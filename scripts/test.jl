
include("modelGeneration.jl")

"Test script for debugging purposes"

node = generateNodes(3)
edge = generateElecEdges(node, 5)
visualizeNetwork(Network(node, edge, ComEdge[]))
