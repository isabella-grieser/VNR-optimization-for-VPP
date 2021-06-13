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
#visualize the generated network with the power outputs of the individual nodes
#where the electrical connections are yellow and the communication lines are red
visualize_network(network)
reliabilities = [ 0.4, 0.5, 0.6]
scenarios = create_scenarios(network.nodes, reliabilities)
print(scenarios)
print("\n")
print(length(scenarios))
print("\n")
print([scenarios[1][2][n] for n in 1:length(network.nodes)])
print("\n")
print([(n.id, get_neighboring_com_nodes_id(n)) for n in network.nodes])

#print(create_scenarios(network.nodes, reliabilities))