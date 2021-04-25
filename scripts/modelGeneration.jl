using GraphRecipes
using GraphPlot
using LightGraphs
using Colors
using Random
using Base.Sort

include("modelStructure.jl")

"""
generateNodes(nodes = 0, power_avg = 80, power_sd = 10, reliability_avg = .70, reliability_sd = .10)

generates all nodes for a network with the defined properties

the reliability values should be below 1
"""
function generateNodes(node_nr = 0, power_avg = 80, power_sd = 10, reliability_avg = .70, reliability_sd = .10)
  nodes = Node[]
  id = 1
  for _ in 1:node_nr
    #reliability of the node
    p = Float16(reliability_avg + reliability_sd*randn(Float16))
    while p>1
      p = Float16(reliability_avg + reliability_sd*randn(Float16))
    end
    push!(nodes, Node(Int64(round(rand(1:128))), Int64(round(rand(1:128))), Int64(round(power_avg + power_sd*randn(Float16))) , p, 
          id, Edge[], Edge[]))
          id = id + 1
  end
  return nodes
end  

"""
generateElecEdges(nodes , edge_scale = length(nodes)*5)

generates all electrical network edges with given nodes and with more or less the amount of edges given in the edge_scale attribute
"""
function generateElecEdges(nodes, edge_scale = length(nodes)*5)
    #use the simple minium distance generation algorithm described in Hines et al.
    #essentially, each node gets edges to all avg_edges nearest nodes and, with a given probability, one more edge
    elec_edges = ElecEdge[]
    avg_edges = Int32(floor(edge_scale/length(nodes)))
    #probability that an extra edge is generated
    p = edge_scale/length(nodes) - floor(edge_scale/length(nodes))
    #if number of avg edges more than node sum -> throw exeption
    if(avg_edges>length(nodes)) 
      throw(ArgumentError("there are too many edges for the network")) 
    end
    for n in nodes
        #get all neighbors
        neighbors = [(e.from) !== n ? e.from : e.to for e in n.elec_edges]
        #create an average number of edges for each node +1 for the stochastic creation
        #with nodes that it is not already connected with
        link_nodes = getNNearestNodes(n,nodes,neighbors, avg_edges+1)  
        #the last node is not used for the edge generation       
        for i in Iterators.take(link_nodes,avg_edges)
          edge =  ElecEdge(n,i)
          push!(elec_edges, edge)
          push!(i.elec_edges, edge)
          push!(n.elec_edges, edge)
        end
        #then create an additional link with a probability p=edges/nodes-floor(edges/nodes)    
        if(rand(Float64) < p && !isempty(link_nodes)) 
          edge =  ElecEdge(n,last(link_nodes))
          push!(elec_edges, edge) 
          push!(last(link_nodes).elec_edges, edge)
          push!(n.elec_edges, edge)
        end   
    end
    return elec_edges  
end

"helper function to get the n nearest nodes"
function getNNearestNodes(node, nodes, neighbor_nodes,  n)
  #creation of a helper structure necessary since a custom comparator does not take 3 parameters and I cannot
  #make the comparator inside the function where I could have access to the parameter node
  pair_nodes =Pair[]
  for i in nodes
     if(i !== node && !(i in neighbor_nodes)) push!(pair_nodes, Pair(node,i)) end
  end
  sort!(pair_nodes; alg=Sort.PartialQuickSort(n))
  #now get the nodes back :(
  return_nodes = Node[]
  j = 1
  #somehow I cant iterate directly though the vector; but with Iterators.take it somehow works (helps against bound errors)
  for i in Iterators.take(pair_nodes,n)
    push!(return_nodes, i.b)
  end
  return return_nodes
end

"""
generateComEdges(nodes)

generates all communication network edges with given nodes
"""
function  generateComEdges(nodes)
    com_edges = ComEdge[]
    return com_edges
end

"""
generateNetwork(nodes , elec_edges, com_edges)

generates a SN based on the nodes, electrical lines and communication lines given as parameters
"""
function generateNetwork(nodes , elec_edges, com_edges)
  return Network(nodes, elec_edges, com_edges)
end

"""
visualizeNetwork(network)

visualizes the given network
"""
function visualizeNetwork(network)
  #add the number of nodes
  g = SimpleGraph(length(network.nodes))
  node_labels = [i.power for i in network.nodes]
  edge_color = Colorant[]
  x = Int64[]
  y = Int64[]
  #add node coordinates
  for n in network.nodes
  push!(x, n.x)
  push!(y, n.y)
  end
  #add elec edges
  for e in network.elec_edges
    add_edge!(g, e.from.id, e.to.id)
    push!(edge_color, colorant"yellow")
  end
  for e in network.com_edges
    add_edge!(g, e.from.id, e.to.id)
    push!(edge_color, colorant"red")
  end
  gplot(g, x,y, nodelabel=node_labels,edgestrokec = edge_color)
end

"helper structure to find the nearest node combination"
struct Pair{T<:Node}
  a::T
  b::T
end

"necessary to find pairs with the minimum distance"
function Base.:isless(x::Pair,y::Pair)
    return (x.a.x-x.b.x)^2+(x.a.y-x.b.y)^2 <= (y.a.x-y.b.x)^2+(y.a.y-y.b.y)^2
end
