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
  for _ in 1:node_nr
    #reliability of the node
    p = Float16(reliability_avg + reliability_sd*randn(Float16))
    while p>1
      p = Float16(reliability_avg + reliability_sd*randn(Float16))
    end
    push!(nodes, Node(Int32(round(rand(1:128))), Int32(round(rand(1:128))), Int32(round(power_avg + power_sd*randn(Float16))) , p))
  end
  return nodes
end  

"""
generateElecEdges(nodes , edge_scale = length(nodes)*5)

generates all electrical network edges with given nodes; 
more or less the amount of edges given in the edge_scale attribute
"""
function generateElecEdges(nodes, edge_scale = length(nodes)*5)
    #use the simple generation algorithm described in Hines et al.
    #essential, each node gets edges to all avg_edges nearest nodes and, with a given probability, one more edge
    elec_edges = ElecEdge[]
    avg_edges = Int32(floor(edge_scale/length(nodes)))
    #probability that an extra edge is generated
    p = edge_scale/length(nodes) - floor(edge_scale/length(nodes))
    #if number of avg edges more than node sum -> throw exeption
    if(avg_edges>length(nodes)) 
      throw(ArgumentError("there are too many edges for the network")) 
    end
    for n in nodes
        #create an average number of edges for each node +1 for the stochastic creation
        link_nodes = getNNearestNodes(n,nodes,avg_edges+1)        
        for i in link_nodes 
          push!(elec_edges, ElecEdge(n,i))
        end
        #then create an additional link with a probability p=edges/nodes-floor(edges/nodes)    
        if(rand(Float64)<p) push!(elec_edges, ElecEdge(n,last(link_nodes))) end   
    end
    return elec_edges  
end

"helper function to get the n nearest nodes"
function getNNearestNodes(node, nodes, n)
  #creation of a helper structure necessary since a custom comparator does not take 3 parameters and I cannot
  #make the comparator inside the function where I could have access to the parameter node
  pair_nodes =Pair[]
  for i in nodes
     if(i !== node) push!(pair_nodes, Pair(node,i)) end
  end
  sort!(pair_nodes; alg=Sort.PartialQuickSort(n))
  #now get the nodes back :(
  return_nodes = Node[]
  for i in [0:n+1]
    #somehow I cant iterate directly though the vector
    #TODO: iterate directly 
    push!(return_nodes, pair_nodes[i].b)
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



"helper structure to find the nearest node combination"
struct Pair{T<:Node}
  a::T
  b::T
end

function Base.:isless(x::Pair,y::Pair)
    return (x.a.x-x.b.x)^2+(x.a.y-x.b.y)^2 <= (y.a.x-y.b.x)^2+(y.a.y-y.b.y)^2
end
