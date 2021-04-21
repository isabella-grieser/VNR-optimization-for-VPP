
include("modelGeneration.jl")

"Test script for debugging purposes"

node = generateNodes(5)
print(generateElecEdges(node, 5))
