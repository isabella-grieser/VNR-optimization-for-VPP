
include("modelGeneration.jl")

node = generateNodes(5)
print(generateElecEdges(node, 5))
