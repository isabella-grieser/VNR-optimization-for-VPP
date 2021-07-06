using JuMP, CPLEX

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")
include("exampleModel.jl")

#print(create_scenarios(network.nodes, reliabilities))

example_network = get_example()

example_vnr1 = VNR(75, 0.95)
example_reliabilities = [0.1, 0.3, 0.5, 0.7, 0.9]
links = [[1,2]]
print([(i, j) for i in 1:length(example_network.nodes) for j in get_neighboring_com_nodes_id(example_network.nodes[i])])
#create_minimum_scenarios(example_network.nodes, example_reliabilities, example_vnr1.reliability)