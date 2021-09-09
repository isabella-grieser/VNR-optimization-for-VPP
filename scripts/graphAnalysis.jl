using GraphRecipes
using GraphPlot
using LightGraphs
using Colors
using Printf
using Distributions

"""
get_dependent_nodes(edge)

get the ids of all dependent nodes of type der or management of an edge 
"""
function get_dependent_nodes(edge)
    nodes = []    
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
        #if one of the two nodes of the edge is the der, then we just return the one der connected through this edge
        if edge.from.type == der
           push!(nodes, edge.from.id) 
        elseif edge.to.type == der
           push!(nodes, edge.to.id)
        end
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
  returns all neighboring node IDs connected through the communication network
"""
function get_neighboring_com_nodes_id(n)
  return [(i.from.id == n.id) ? i.to.id : i.from.id for i in n.com_edges]
end
"""
  create_scenarios(nodes, reliabilities)

  creates and returns all scenario and its probabilities
  - 'nodes' : the nodes considered in the scenario creation
  - 'reliabilities' : the reliability levels considered in the scenario creation
"""
function create_scenarios(nodes, reliabilities)
  #first, create the single reliability scenarios for each node
  single_scenarios = []
  for n in nodes
    if n.power > .01
      push!(single_scenarios, [(r, calculate_power(n, r)) for r in reliabilities])
    else
      push!(single_scenarios, [(1, 0)])     
    end
  end
  #then calculate the cartesian product
  all_scenarios = []
  for s in single_scenarios
    if isempty(all_scenarios)
      all_scenarios = s
    else
      all_scenarios = calculate_cartesian(all_scenarios, s)
    end
  end
  return all_scenarios
end
"""
  helper function that calculates the cartesian of two arrays
"""
function calculate_cartesian(arr1, arr2)
  cartesian = []
  for a1 in arr1
    for a2 in arr2
      push!(cartesian, (a1[1]*a2[1], [a1[2]; a2[2]]))
    end
  end
  return cartesian
end

"""
  calculates the power output given a reliability level
"""
function calculate_power(n, r)
  p =  (n.sd > 0) ? quantile(Normal(n.power, n.sd), r) : 0
  return (p > 0) ? p : 0
end

"""
  create_minimum_scenarios(nodes, com_links, reliabilities, vnr_reliability)
  
  creates and returns all scenarios and its probabilities minus the scerarios that need to be fulfilled anyway
"""
function create_minimum_scenarios(nodes, com_edges, reliabilities, vnr_reliability; scenarios = nothing)

  rel = 1 - vnr_reliability
  #calculate the cartesian product
  #there should be a more efficient way to calculate all this (because we only need parts of it)
  #but I dont know how to calculate an n-cartesian efficently given the heuristic constraints
  if scenarios === nothing
    all_scenarios = create_scenarios(nodes, reliabilities)
  end
  #calculate the lowest com_edge factor of the network 
  sum_pi = sum(all_scenarios[i][1]*(1-com_edges[l].reliability)
        for i in 1:length(all_scenarios) for l in 1:length(com_edges))
  sum_pi += sum((s)->s[1],all_scenarios)
  min_com_factor = minimum([(1-e.reliability) for e in com_edges if e.reliability < 1.0]) 
  min_com_factor *= (1/sum_pi) 
  #this implementation of removing unecessary scenarios is kind of inefficient I guess
  #sort the list by scenario probabilities
  sort!(all_scenarios, by=x->x[1])
  all_essential_scenarios = []
  #the current scenario probability
  current_probability = 0
  #this only says if the probability is higher than the allowed probability
  next_is_last = false
  for i in 1:length(all_scenarios)
    probability = all_scenarios[i][1]
    if current_probability == probability
      #add the scenario to the essential ones 
      push!(all_essential_scenarios, all_scenarios[i])
      continue
    elseif next_is_last == true
      #if this is the last scenario with a probability that is interesting for us 
      if current_probability == (min_com_factor*probability)
        #we want to get all scenarios with the same probability
        push!(all_essential_scenarios, all_scenarios[i])
        continue
      else 
        #all necessary scenarios were extracted
        break
      end
    else 
      if (min_com_factor*probability) > rel
        #else we put the flag that we only want the next elements (defined in the current_probability) and then stop
        next_is_last = true
      current_probability = probability        
      end
      push!(all_essential_scenarios, all_scenarios[i])
    end
  end

  return all_essential_scenarios
end

"""
visualize_vnr(network)

visualizes the given vnr and saves it if necessary

- 'network' : the used network 
- 'active_nodes' : the nodes activated in the embedding
- 'active_com_edges' : the communication links activated in the embedding
- 'save' : if the visualization should be saved
- 'name' : if the visualization should be saved; the name under it should be saved
"""
function visualize_vnr(network, active_nodes, active_com_edges; save = false, name = "1")
  #add the number of nodes
  g = SimpleGraph(length(network.nodes))
  node_labels = String[]
  
  nodestroke = [0.05 for i in network.nodes]
  node_circles = []
  node_color = Colorant[] 
  edge_color = Colorant[] 

  #config
  for (i, x) in zip(network.nodes, active_nodes[2,:])
    if i.type === der
      push!(node_labels, string(i.power))   
    elseif i.type === feeder
      push!(node_labels, "f")
    elseif i.type === substation
      push!(node_labels, "s")
    elseif i.type === gateway
      push!(node_labels, "g")
    elseif i.type === tower
      push!(node_labels, "t")
    elseif i.type === management
      push!(node_labels, "m") 
      push!(node_color, colorant"cornsilk2")
      push!(node_circles, colorant"black")
      continue            
    end
    if x > 0.9
      push!(node_color, colorant"cornsilk2")
      push!(node_circles, colorant"black") 
    else
      push!(node_color, colorant"white")
      push!(node_circles, colorant"black")
    end   
  end

  #add node coordinates  
  x = Int64[n.x for n in network.nodes]
  y = Int64[n.y for n in network.nodes]
  
  for e in network.com_edges
    
    if active_com_edges[e.id] > 0.9
        add_edge!(g, e.from.id, e.to.id)
        push!(edge_color, colorant"red")
    #else 
        #push!(edge_color, colorant" lightsalmon")
    end
  end
  if save 
    draw(PNG(pwd()*"\\fig\\"*name*".png", 16cm, 16cm),   
    gplot(g, x,y, nodelabel=node_labels, nodefillc = node_color, nodestrokec = node_circles, 
    nodestrokelw = nodestroke, edgestrokec = edge_color))
  else 
  #configuration described in https://github.com/JuliaGraphs/GraphPlot.jl/blob/master/src/plot.jl
  gplot(g, x,y, nodelabel=node_labels, nodefillc = node_color, nodestrokec = node_circles, 
        nodestrokelw = nodestroke, edgestrokec = edge_color)
  end
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