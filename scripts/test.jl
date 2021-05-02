
include("modelGeneration.jl")

"Test script for debugging purposes"

#define the average number of nodes in a network cluster
node_cluster = 3
#define the number of clusters in the network
cluster_sum = 3


network = generateNetwork(node_cluster, cluster_sum)
#visualize the generated network with the power outputs of the individual nodes
#where electrical connections are yellow and communication lines are red
visualizeNetwork(network)