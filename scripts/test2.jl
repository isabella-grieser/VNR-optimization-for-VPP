using JuMP, CPLEX

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")

#define the average number of nodes in a network cluster
node_cluster = 3
#define the number of clusters in the network
cluster_sum = 3

#generate the network containing both the electrical and communication network; 
#all other values defined in the text are generated with standard values defined in the script
network = generate_network(node_cluster, cluster_sum)
#visualize the generated network with the power outputs of the individual nodes
#where the electrical connections are yellow and the communication lines are red
visualize_network(network)

#VPP properties
power = 300
reliability = .95

vnr = VNR(power, reliability)

model = Model(CPLEX.Optimizer)

#get the indexes of all ders in the model
ders = filter(n -> n.type == der, network.nodes)

#the activation of the nodes, electrical edges and communication edges are all defined as binary vectors
@variable(model, x[1:length(ders)], binary = true) 
@variable(model, y[1:length(ders),1:length(network.com_edges)], binary = true) 
@variable(model, z[1:length(ders),1:length(network.elec_edges)], binary = true)



#mapping constraints
@constraint(model, c1, sum(x[i] for i in 1:length(ders)) >= 1)
#for the link constraints we create a length(network.com_edges)xlength(ders) matrix to define each DER-VMO connections
@constraint(model, c2[i = 1:length(ders)], sum(y[i,j] for j in 1:length(network.com_edges)) >= 1)
@constraint(model, c3[i = 1:length(ders)], sum(z[i,j] for j in 1:length(network.elec_edges)) >= 1)

#vmo constraint
#x_v is always the vmo -> we work with the index of the vmo
index_vmo = findfirst(n -> n.type == management, network.nodes)

#reverse dummy binary variables that define y_jin for the multi-commodity flow constraints
@variable(model, y_reverse[1:length(ders),1:length(network.com_edges)], binary = true) 
@variable(model, z_reverse[1:length(ders),1:length(network.elec_edges)], binary = true)
#dummy variable for flow commodity constraint: for each link (u,v), x[i] = 1, all x[j] = 0,j!=i and x[vmo] = -1
#-> x_dummy can be 1,0 or -1
#this should be almost an identity matrix, but with -1 at the index of the vmo
@variable(model, x_dummy[1:length(ders),1:length(network.nodes)], binary = true)
@constraint(model,c5[i = 1:length(ders),j = 1:length(network.nodes);ders[i].id != j && j != index_vmo],
           x_dummy[i,j] == 0)
@constraint(model,c6[i = 1:length(ders)], x_dummy[i,index_vmo] == x[i])
@constraint(model,c7[i = 1:length(ders)], x_dummy[i,ders[i].id] == x[i])

#multi-commodity flow constraints
@constraint(model,c8[uv = 1:length(ders),i = 1:length(network.nodes); i != index_vmo],
           (sum((y[uv,j.id]-y_reverse[uv,j.id]) for j in network.nodes[i].com_edges)) - x_dummy[uv,i] == 0)
@constraint(model,c9[uv = 1:length(ders)], x_dummy[uv,index_vmo] +
           (sum((y[uv,j.id]-y_reverse[uv,j.id]) for j in network.nodes[index_vmo].com_edges))  == 0) 
@constraint(model,c10[uv = 1:length(ders),i = 1:length(network.nodes); i != index_vmo],
           (sum((z[uv,j.id]-z_reverse[uv,j.id]) for j in network.nodes[i].elec_edges)) - x_dummy[uv,i] == 0) 
@constraint(model,c11[uv = 1:length(ders)], x_dummy[uv,index_vmo] +
           (sum((z[uv,j.id]-z_reverse[uv,j.id]) for j in network.nodes[index_vmo].elec_edges)) == 0)  


           #maybe search for a better value that is not random for this variable
Z = 0.2
p_node = [(1/Z)*prod((a.id==i.id) ? (1-a.reliability) : a.reliability for a in network.nodes)*prod(
          c.reliability for c in network.com_edges) for i in ders]
p_link = [(1/Z)*prod( a.reliability for a in network.nodes)*prod(
          (c.id==i.id) ? (1-c.reliability) : c.reliability for c in network.com_edges) 
            for i in network.com_edges]

#scenario variables 
@variable(model,zeta[1:length(ders)], binary = true)
@variable(model,zeta_link[1:length(network.com_edges)], binary = true)

#scenario node constraint
#second method in order to describe this constraint
@constraint(model, c12[i = 1:length(ders)], zeta[i]*vnr.power 
    + sum(((ders[n].id == ders[i].id) ? 0 : ders[n].power*x[n]) for n in 1:length(ders)) >= vnr.power)

#scenario link constraints
@constraint(model, c13[i = 1:length(network.com_edges)], zeta_link[i]*vnr.power 
    + sum(((any(m -> ders[n].id == m.id, get_dependent_nodes(network.com_edges[i]))) ? 0 : ders[n].power*x[n])
       for n in 1:length(ders)) >= vnr.power)
#calculate the reliability
@constraint(model, c14, sum(zeta[i]*p_node[i] for i in 1:length(ders)) + 
    sum(zeta_link[i]*p_link[i] for i in 1:length(network.com_edges)) <= 1.0-vnr.reliability)

#link summary constraint
@variable(model, y_sum[1:length(network.com_edges)], binary = true) 
@variable(model, z_sum[1:length(network.elec_edges)], binary = true)

#these constraints summarize the link activations; If a link was activated on any virtual link, then the link
#is activated on the vnr
@constraint(model, [i = 1:length(ders),j = 1:length(network.com_edges)], y_sum[j] >= y[i,j])
@constraint(model, [i = 1:length(ders),j = 1:length(network.com_edges)], y_sum[j] >= y_reverse[i,j])
@constraint(model, [i = 1:length(ders),j = 1:length(network.elec_edges)],z_sum[j] >= z[i,j])
@constraint(model, [i = 1:length(ders),j = 1:length(network.elec_edges)],z_sum[j] >= z_reverse[i,j])

#objective function -> we aim to minimize this function
@objective(model, Min, sum(x[i]*ders[i].cost for i in 1:length(ders)) 
           + sum(y_sum[i]*network.com_edges[i].cost for i in 1:length(network.com_edges)) 
           + sum(z_sum[i]*network.elec_edges[i].cost for i in 1:length(network.elec_edges)))

        
optimize!(model)

visualize_vnr(network, ders, value.(x), value.(y_sum), value.(z_sum))
