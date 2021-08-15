include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")
include("exampleModel.jl")
include("dynamicModelAnalysis.jl")

#THIS FILE WAS ONLY CREATED FOR TESTING PURPOSES

#print(create_scenarios(network.nodes, reliabilities))

#model size parameters
clusters = 3
nodes_per_cluster = 2

model = generate_network(clusters, nodes_per_cluster)

model = get_example()
dynamic_model_analysis(.95, model = model)

example_vnr1 = VNR(75, 0.95)
example_reliabilities = [0.1, 0.3, 0.5, 0.7, 0.9]
links = [[1,2]]