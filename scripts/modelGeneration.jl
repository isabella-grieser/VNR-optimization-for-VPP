using GraphRecipes
using GraphPlot
using LightGraphs
using Colors
using Random
using Base.Sort

include("modelStructure.jl")

"""
function generateNetwork(node_cluster = 5, clusters = 5, cost_param1 = 1, cost_param2 = 2, cost_param3 = 1, size_array = [], 
  radius_1 = 30, radius_2 = 10, power_avg = 80, power_sd = 10, reliability_avg = .70, reliability_sd = .10)

generates the electrical distribution and communication network based on a radial (star) topology
with the given node and cluster amount; the individual cluster sizes can also be given as an array

#arguments
- 'node_cluster' : number of ders per cluster 
- 'clusters' : number of clusters
- 'cost_param1' : cost parameter for the DER nodes
- 'cost_param2' : cost parameter for the electrical links
- 'cost_param3' : cost parameter for the communication links
- 'size_array' : an array with the individual number of nodes per cluster (if clusters with different amount of nodes are desired)
- 'radius_1' : the max distance between feeder/gateway and substation/tower
- 'radius_2' : the max distance between substation/tower and DERs
- 'power_avg, power_sd, reliability_avg, reliability_sd' : parameters necessary for DER generation
- 'reliability_avg_com, reliability_sd_com' : the reliability parameters for the communication network
"""
function generate_network(node_cluster = 5, clusters = 5, cost_param1 = 1, cost_param2 = 2, cost_param3 = 1, size_array = [], 
  radius_1 = 20, radius_2 = 5, power_avg = 80, power_sd = 10, reliability_avg = .70, reliability_sd = .10,
  reliability_avg_com = .80, reliability_sd_com = .10)

  elec_edges = ElecEdge[]
  com_edges = ComEdge[]
  nodes = Node[]
  #this is a helper array for the der
  second_elec_roots = Node[]
  #this is a helper array for the communication network generation
  leaf_nodes = Node[]
  #parameters for the index generation
  id = 1
  elec_id = 1
  com_id = 1
  #coordinate value range
  coord_min = 1
  coord_max = 64
  #first, generate the electrical network; based on that we will later generate the communication network
  #first,generate the root node


  root = Node(feeder, id, Int64(round(rand(coord_min: coord_max))), Int64(round(rand(coord_min:coord_max))), 0, 
              1.0, 0.0, Edge[], Edge[])
  push!(nodes, root)
  id += 1

  #calculate cluster size
  if !isempty(size_array) 
    clusters = length(size_array) 
  end

  #create the second level of nodes
  for i in 1:clusters
    #generate the nodes inside a square (faster/easier to generate than in a circle) with the respective radius_1
    x = calculateCoordinate(root.x, radius_1, coord_min, coord_max)
    y = calculateCoordinate(root.y, radius_1, coord_min, coord_max)
    sub = Node(substation, id, x, y, 0, 1.0, 0.0, Edge[],  Edge[])
    push!(nodes, sub)
    #generate the edge between root and substation
    edge =  ElecEdge(root, sub, Float64(cost_param2*calculateLength(root, sub)), elec_id)
    push!(root.elec_edges, edge)
    push!(sub.elec_edges, edge)
    push!(elec_edges, edge)
    push!(second_elec_roots, sub)
    id += 1
    elec_id += 1
  end

  #create DER if the amount of nodes per cluster is given as an array
  if !isempty(size_array) 
    for (i,v) in enumerate(size_array)
      node = second_elec_roots[i]  
      for n in 1:v
        d = generateDer(node, power_avg, power_sd, reliability_avg, reliability_sd, id, radius_2, cost_param1, coord_min, coord_max)  
        #create the edge
        edge = ElecEdge(node, d, Float64(cost_param2*calculateLength(node, d)), elec_id)
        push!(node.elec_edges, edge)
        push!(d.elec_edges, edge)
        push!(elec_edges, edge)
        push!(leaf_nodes, d)
        push!(nodes, d)
        id += 1
        elec_id += 1
      end
    end 
  else 
    #else create DER with the average amount numbers 
    for i in 1:clusters
      node = second_elec_roots[i]     
      for n in 1:node_cluster
        d = generateDer(node, power_avg, power_sd, reliability_avg, reliability_sd, id, radius_2, cost_param1, coord_min, coord_max)
        #create the edge
        edge = ElecEdge(node, d, Float64(cost_param2*calculateLength(node, d)), elec_id)
        push!(node.elec_edges, edge)
        push!(d.elec_edges, edge)
        push!(elec_edges, edge)
        push!(leaf_nodes, d)
        push!(nodes, d)
        id += 1
        elec_id += 1
      end
    end
  end
  #electrical network is finished

  #generate the vpp management office node
  #just get the first substation
  sub = second_elec_roots[1]
  x = calculateCoordinate(sub.x, radius_2, coord_min, coord_max)
  y = calculateCoordinate(sub.y, radius_2, coord_min, coord_max)
  mngmt = Node(management, id, x, y, 0, 1.0, 0.0, Edge[],  Edge[])
  push!(nodes, mngmt)
  push!(leaf_nodes, mngmt)
  id += 1 

  edge =  ElecEdge(mngmt, sub, Float64(cost_param2*calculateLength(mngmt, sub)), elec_id)
  push!(mngmt.elec_edges, edge)
  push!(sub.elec_edges, edge)
  push!(elec_edges, edge)
  elec_id = elec_id + 1

  #now generate a different set of root nodes for the communication network (with different coordinates)
  com_root = Node(gateway, id,  Int64(round(rand(coord_min: coord_max))), Int64(round(rand(coord_min:coord_max))), 
              0, 1.0, 0.0, Edge[], Edge[])
  push!(nodes, com_root)
  id += 1

  towers = Node[]
  #create the second level of nodes
  for i in 1:clusters
    x = calculateCoordinate(com_root.x, radius_1, coord_min, coord_max)
    y = calculateCoordinate(com_root.y, radius_1, coord_min, coord_max)
    tow = Node(tower, id, x, y, 0, 1.0, 0.0, Edge[], Edge[])
    push!(nodes, tow)
    push!(towers, tow)
   #generate the edge between root and tower
   #here we put the reliability of the edge to 1.0 because we assume that the infrastrucute is reliable
    edge = ComEdge(com_root, tow, Float64(cost_param3), com_id, 1.0)
    push!(com_root.com_edges, edge)
    push!(tow.com_edges, edge)
    push!(com_edges, edge)
    id += 1
    com_id += 1
  end

  #now connect all ders to the nearest towers 
  for n in leaf_nodes
    tow = min(n, towers)
    #calculate the reliability of the connection
    p = Float64(reliability_avg_com + reliability_sd_com*randn())
    while p > 1.0
      p =  Float64(reliability_avg_com + reliability_sd_com*randn())
    end   
    #generate the edge between tower and der
    edge = ComEdge(tow, n, Float64(cost_param3), com_id, p)
    push!(tow.com_edges, edge)
    push!(n.com_edges, edge)
    push!(com_edges, edge)  
    com_id += 1
  end

  #if a tower is not connected to any der -> remove it because it is useless 
  for i in towers
    #less than two edges => i is only connected with the gateway
    if length(i.com_edges)<2
      #remove the edge from the gateway and the edge array
      ind = findfirst(n->n.from.id == i.id || n.to.id == i.id, com_root.com_edges)
      edge = com_root.com_edges[ind]
      deleteat!(com_edges, findfirst(n -> n === edge, com_edges))      
      deleteat!(com_root.com_edges, ind)
      #remove the node
      deleteat!(nodes, findfirst(n -> n.id == i.id, nodes))
      #the id of the com nodes need to be recalculated, else the graph cannot be visualized properly
      for j in towers
        if j.id>i.id
          j.id -= 1
        end
      end
      #we also change the id of the com edges for the later jump constraints
      for e in com_edges
        if e.id>edge.id
          e.id -= 1
        end
      end
    end
  end

  for i in leaf_nodes
    #now check if there is really a com edge for each leaf node 
    if(isempty(i.com_edges))
      throw(e)
    end    
  end

  return Network(nodes, elec_edges, com_edges) 

end

"helper function to generate a coordinate value within the radius "
function calculateCoordinate(ref_value, radius, coord_min, coord_max)
  value = Int64(round((ref_value - radius) + 2*radius*randn(Float16)))

  while value < coord_min || value > coord_max || value == ref_value
    value = Int64(round((ref_value - radius) + 2*radius*randn(Float16)))
  end

  return value
end

"helper function to calculate the length of the edge"
function calculateLength(x, y)
  return abs(x.x - y.x) + abs(x.y - y.y)
end


"helper function which generates the distributed energy resource node"
function generateDer(root, power_avg, power_sd, reliability_avg, reliability_sd, id, radius, cost_param, coord_min, coord_max)

  #reliability of the node
  p = Float64(reliability_avg + reliability_sd*randn())
  while p > 1.0
    p =  Float64(reliability_avg + reliability_sd*randn())
  end

  #generate the nodes inside a square (faster/easier to generate than in a circle) with the respective radius_1
  x = calculateCoordinate(root.x, radius, coord_min, coord_max)
  y = calculateCoordinate(root.y, radius, coord_min, coord_max)  

  power = Int64(round(power_avg + power_sd*randn(Float16)))
  return Node(der, id, x, y, power , p, Float64(cost_param*power), Edge[], Edge[])
end

"helper function to find the nearest node"
function  min(value, array)
  min = typemax(Int)
  min_node = first(array)
  for i in array
    dist = abs(value.x-i.x) + abs(value.y-i.y)
    if dist <= min 
      min_node = i
      min = dist
    end
  end
  return min_node
end

"""
visualizeNetwork(network)

visualizes the given network
"""
function visualize_network(network)
  #add the number of nodes
  g = SimpleGraph(length(network.nodes))
  node_labels = String[]
  
  #config
  for i in network.nodes
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
    end
  end
  
  node_color = [colorant"white" for i in network.nodes]
  node_circles = [colorant"black" for i in network.nodes]
  nodestroke = [0.05 for i in network.nodes]
  edge_color = Colorant[]

  #add node coordinates  
  x = Int64[n.x for n in network.nodes]
  y = Int64[n.y for n in network.nodes]
  
  #the ids begin with 0 but for the visualization we need to add it with one; else the visualization will be a mess
  #add elec edges
  for e in network.elec_edges
    add_edge!(g, e.from.id, e.to.id)
    push!(edge_color, colorant"yellow")
  end

  #add com edges
  for e in network.com_edges
    add_edge!(g, e.from.id, e.to.id)
    push!(edge_color, colorant"red")
  end
  #configuration described in https://github.com/JuliaGraphs/GraphPlot.jl/blob/master/src/plot.jl
  gplot(g, x,y, nodelabel=node_labels, nodefillc = node_color, nodestrokec = node_circles, 
        nodestrokelw = nodestroke, edgestrokec = edge_color)
end
