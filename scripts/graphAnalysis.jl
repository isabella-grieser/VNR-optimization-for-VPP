using GraphRecipes
using GraphPlot
using LightGraphs
using Colors
using Printf

"""
get_dependent_nodes(edge)

get all dependent nodes of type der of an edge 
"""
function get_dependent_nodes(edge)
    nodes = Node[]    
    if(edge.from.type == gateway || edge.to.type == gateway)
        #get the dependent nodes of all subedges
        if (edge.from.type == tower)
          for e in edge.from.com_edges
            if(e.id != edge.id)
                append!(nodes, get_dependent_nodes(e))
            end
          end
        else
            for e in edge.to.com_edges
                if(e.id != edge.id)
                    append!(nodes, get_dependent_nodes(e))
                end
            end
        end
    else
        #if one of the two nodes of the edge is not the gateway, then we just return the one der connected through this edge
        (edge.from.type == der) ?  push!(nodes, edge.from) : push!(nodes, edge.to)
    end
    return nodes
end

"""
  returns all neighboring nodes connected through the communication network
"""
function get_neighboring_com_edges(n)
  return [(i.from.id == n.id) ? i.to : i.from for i in n.com_edges]
end

"""
  returns all neighboring nodes connected through the electrical network
"""
function get_neighboring_elec_edges(n)
  return [(i.from.id == n.id) ? i.to : i.from for i in n.elec_edges]
end

"""
visualize_vnr(network)

visualizes the given vnr
"""
function visualize_vnr(network, ders, active_nodes, active_com_edges, active_elec_edges)
  #add the number of nodes
  g = SimpleGraph(length(network.nodes))
  node_labels = String[]
  
  nodestroke = [0.05 for i in network.nodes]
  node_circles = []
  node_color = Colorant[] 
  edge_color = Colorant[] 

  #config
  for i in network.nodes
    if i.type === der
      push!(node_labels, string(i.power))
      ind = findfirst(n -> n.id == i.id, ders) 
      if active_nodes[ind] > 0.9
        push!(node_color, colorant"cornsilk2")
        push!(node_circles, colorant"black") 
      else
        push!(node_color, colorant"white")
        push!(node_circles, colorant"black")
      end     
    elseif i.type === feeder
      push!(node_labels, "f")
      push!(node_color, colorant"white")
      push!(node_circles, colorant"black")
    elseif i.type === substation
      push!(node_labels, "s")
      push!(node_color, colorant"white")
      push!(node_circles, colorant"black")
    elseif i.type === gateway
      push!(node_labels, "g")
      push!(node_color, colorant"white")
      push!(node_circles, colorant"black")
    elseif i.type === tower
      push!(node_labels, "t")
      push!(node_color, colorant"white")
      push!(node_circles, colorant"black")
    elseif i.type === management
      push!(node_labels, "m") 
      push!(node_color, colorant"cornsilk2")
      push!(node_circles, colorant"black")            
    end
  end

  #add node coordinates  
  x = Int64[n.x for n in network.nodes]
  y = Int64[n.y for n in network.nodes]
  
  #add elec edges
  for e in network.elec_edges
    
    if active_elec_edges[e.id] > 0.9
        add_edge!(g, e.from.id, e.to.id)
        push!(edge_color, colorant"gold")
    #else 
    #    push!(edge_color, colorant"floralwhite")
    end
  end

  #add com edges
  for e in network.com_edges
    
    if active_com_edges[e.id] > 0.9
        add_edge!(g, e.from.id, e.to.id)
        push!(edge_color, colorant"red")
    #else 
        #push!(edge_color, colorant" lightsalmon")
    end
  end
  #configuration described in https://github.com/JuliaGraphs/GraphPlot.jl/blob/master/src/plot.jl
  gplot(g, x,y, nodelabel=node_labels, nodefillc = node_color, nodestrokec = node_circles, 
        nodestrokelw = nodestroke, edgestrokec = edge_color)
end
"""
helper function that prints the graph information in a non-graphic format for debugging purposes
"""
function show_graph_information(network, shownode = false)
  if shownode
    for n in network.nodes
      @printf("node %i: has %i com_connections and %i elec_connections\n", n.id, length(n.com_edges), length(n.elec_edges))
    end    
  end
  for c in network.com_edges
    @printf("com_edge %i: from %i to %i.\n",c.id, c.from.id, c.to.id)
  end
  for e in network.elec_edges
    @printf("elec_edge %i: from %i to %i.\n",e.id, e.from.id, e.to.id)
  end
end