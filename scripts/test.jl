
include("modelGeneration.jl")
include("graphAnalysis.jl")
using JuMP, GLPK

"Test script for debugging purposes"

#define the average number of nodes in a network cluster
node_cluster = 3
#define the number of clusters in the network
cluster_sum = 3


network = generate_network(node_cluster, cluster_sum)
#visualize the generated network with the power outputs of the individual nodes
#where electrical connections are yellow and communication lines are red
visualize_network(network)

nodes = get_dependent_nodes(network.com_edges[2])


model = Model(GLPK.Optimizer)

#the activation of the nodes, electrical edges and communication edges are all defined as binary vectors
@variable(model, x[1:length(network.nodes)], binary = true) 
@variable(model, y[1:length(network.nodes),1:length(network.com_edges)], binary = true) 
@variable(model, z[1:length(network.nodes),1:length(network.elec_edges)], binary = true)

index_vmo = findfirst(n -> n.type == management, network.nodes)
i = 4
#reverse dummy binary variables that define y_jin for the multi-commodity flow constraints
@variable(model, y_reverse[1:length(network.nodes),1:length(network.com_edges)], binary = true) 
@variable(model, z_reverse[1:length(network.nodes),1:length(network.elec_edges)], binary = true)
#dummy variable for flow commodity constraint: for each link (u,v), x[i] = 1 and all x[j] = 0,j!=i
#this should be almost an identity matrix, but with -1 at the index of the vmo
@variable(model, x_dummy[1:length(network.nodes),1:length(network.nodes)], binary = true)
@constraint(model,[i = 1:length(network.nodes),j = 1:length(network.nodes);i != j && j != index_vmo],x_dummy[i,j] == 0)
@constraint(model,[i = 1:length(network.nodes);i!=index_vmo],x_dummy[i,index_vmo] == -1)
@constraint(model,[i = 1:length(network.nodes)],x_dummy[i,i] == x[i])
@constraint(model,x_dummy[index_vmo,index_vmo] == 0)

#multi-commodity flow constraints
@constraint(model,c5[i = 1:length(network.nodes),uv = 1:length(network.nodes); uv != index_vmo],
            (sum((y[uv,j.id]-y_reverse[uv,j.id]) for j in network.nodes[i].com_edges)) == x[uv,i])   
@constraint(model,c6[i = 1:length(network.nodes),uv = 1:length(network.nodes); uv != index_vmo],
            (sum((z[uv,j.id]-z_reverse[uv,j.id]) for j in network.nodes[i].elec_edges)) == x[uv,i])