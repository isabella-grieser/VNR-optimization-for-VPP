
using JuMP, CPLEX

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")

#define the average number of nodes in a network cluster
node_cluster = 2
#define the number of clusters in the network
cluster_sum = 2

#generate the network containing both the electrical and communication network; 
#all other values defined in the text are generated with standard values defined in the script
network = generate_network(node_cluster, cluster_sum)

#VPP properties
power = 100
reliability = .95

vnr = VNR(power, reliability)

#model = Model(with_optimizer(CPLEX.Optimizer))
model = direct_model(CPLEX.Optimizer())
#get the indexes of all ders in the model
ders = filter(n -> n.type == der, network.nodes)

#the activation of the nodes, all defined as binary vectors
#the first x is the vmo node, the second x are the der nodes
@variable(model, x[1:2, 1:length(network.nodes)], binary = true) 

#mapping constraints
@constraint(model, c1, sum(x[1, i] for i in 1:length(network.nodes)) == 1)
@constraint(model, c2, sum(x[2, i] for i in 1:length(network.nodes)) >= 1)

#now we define that the vmo node must be mapped to the specific substrate vmo
#vmo constraint; the vmo should be on (x,y) = (1,1)
@constraint(model, c3[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].x)
@constraint(model, c4[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].y)
@constraint(model, c5[i = 1:length(network.nodes)], x[2, i] => {network.nodes[i].x >= 2})
@constraint(model, c6[i = 1:length(network.nodes)], x[2, i] => {network.nodes[i].y >= 2})
#extra condition: only nodes with a power > 0 can be used to map the virtual DER
@constraint(model, c7[i = 1:length(network.nodes)], x[2, i] => {network.nodes[i].power >= 1})
#for the link constraints we create a length(network.com_edges)xlength(ders) matrix to define each DER-VMO connections
@variable(model, y[uvs = 1:length(ders), i = 1:length(network.nodes), j = 1:length(network.nodes)], binary = true)
@constraint(model, c8[uvs = 1:length(ders)], sum(y[uvs,i,j] for i in 1:length(network.nodes)
                                            for j in 1:length(network.nodes)) >= 1)

#this variable defines for each (i,j)-link which node is i (the vmo is always j)
@variable(model, uv[i = 1:length(ders), j = 1:length(network.nodes)], binary = true)
@constraint(model, c9[i = 1:length(ders)], x[ders[i].id] => {uv[i, ders[i].id] == 1})
@constraint(model, c10[i = 1:length(ders), j = 1:length(network.nodes); ders[i].id != j], uv[i, j] == 0)

#multi-commodity flow constraint, u are the ders, v is the vmo
@constraint(model, c11[uvs = 1:length(ders),i = 1:length(network.nodes)],
           sum((y[uvs,i,j] - y[uvs,j,i]) for j in get_neighboring_com_nodes_id(network.nodes[i])) == (uv[uvs, i] - x[1, i]))
#all reliabilities considered in this scenario
reliabilities = [ 0.4, 0.5, 0.6, 0.7]
Z = 100.0
#scenario values; is an array of tuples(that define the power outputs in a specific scenario and the probability of the scenario)
scenario_outputs = create_scenarios(network.nodes, reliabilities)
#scenario variables 
@variable(model,zeta[1:length(scenario_outputs)], binary = true)

#scenario node constraint; go over all scenarios and check if the power constraint is solved 
@constraint(model, c12[i = 1:length(scenario_outputs)], zeta[i]*vnr.power 
    + sum(x[2,n]*scenario_outputs[i][2][n] for n in 1:length(network.nodes)) >= vnr.power)

#calculate the reliability
@constraint(model, c13, sum(zeta[i]*scenario_outputs[i][1] for i in 1:length(scenario_outputs)) <= 1.0-vnr.reliability)

#link summary constraint
@variable(model, y_sum[1:length(network.com_edges)], binary = true) 

c = network.com_edges
n = network.nodes
#these constraints summarize the link activations for easier calculation; 
#If a link was activated on any virtual link, then the link is activated on the vnr
@constraint(model, c14[uvs = 1:length(ders), h = 1:length(network.com_edges)], y_sum[h] >= y[uvs, c[h].from.id, c[h].to.id])
@constraint(model, c15[uvs = 1:length(ders), h = 1:length(network.com_edges)], y_sum[h] >= y[uvs, c[h].to.id, c[h].from.id])
#power unit costs for the ders
lambda = 2.0
lambda_com_edge = 2.0
#objective function -> we aim to minimize this function
@objective(model, Min, sum(x[i]*network.nodes[i].power*lambda for i in 1:length(network.nodes))
                       + sum(y_sum[i]*lambda_com_edge for i in 1:length(network.com_edges))) 

display(objective_function(model))
display(model)

optimize!(model)

#get the results of the optimization
objective_value(model)

visualize_vnr(network, value.(x), value.(y_sum))
