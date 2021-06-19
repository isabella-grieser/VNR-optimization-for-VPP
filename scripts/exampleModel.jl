include("modelGeneration.jl") 

"""
creates an unchanged model example for calculation purposes
"""
function get_example()

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

  #variables of the example model with two der nodes
  power1 = 60
  sd1 = 10.0
  power2 = 30
  sd2 = 5.0  
  #x and y coordinates for all nodes; index equals the node id
  x = [5 , 10 , 5 , 12 , 3 , 1,  9 , 2 , 10]
  y = [5 , 3 , 10 , 5 , 7 , 1, 7,  4 , 11]
  com_rel = 0.7


  root = Node(substation, id, x[id], y[id], 0, 
              0.0, Edge[], Edge[])
  push!(nodes, root)
  id += 1
  
  #create two substations
  sub1 = Node(feeder, id, x[id], y[id], 0, 0.0, Edge[],  Edge[])
  id += 1
  sub2 = Node(feeder, id, x[id], y[id], 0, 0.0, Edge[],  Edge[])
  id += 1
  push!(nodes, sub1)
  push!(nodes, sub2)
  edge1 =  ElecEdge(root, sub1, 0.0, elec_id)
  elec_id += 1
  edge2 =  ElecEdge(root, sub2, 0.0, elec_id)
  elec_id += 1
  push!(root.elec_edges, edge1)
  push!(root.elec_edges, edge2)
  push!(sub1.elec_edges, edge1)
  push!(sub2.elec_edges, edge2)
  push!(elec_edges, edge1)
  push!(elec_edges, edge2)
  push!(second_elec_roots, sub1)
  push!(second_elec_roots, sub2)

  d1 =  Node(der, id, x[id], y[id], power1,  sd1, Edge[], Edge[])  
  #create the edge
  edge3 = ElecEdge(sub1, d1, 0.0, elec_id)
  push!(sub1.elec_edges, edge3)
  push!(d1.elec_edges, edge3)
  push!(elec_edges, edge3)
  push!(leaf_nodes, d1)
  push!(nodes, d1)
  id += 1
  elec_id += 1

  d2 =  Node(der, id, x[id], y[id], power2, sd2, Edge[], Edge[]) 
  #create the edge
  edge4 = ElecEdge(sub2, d2, 0.0, elec_id)
  push!(sub2.elec_edges, edge4)
  push!(d2.elec_edges, edge4)
  push!(elec_edges, edge4)
  push!(leaf_nodes, d2)
  push!(nodes, d2)
  id += 1
  elec_id += 1
  #electrical network is finished

  #generate the vpp management office node
  #the node is fixed at (1,1)
  mngmt = Node(management, id, 1, 1, 0, 0.0, Edge[],  Edge[])
  sub3 = min(mngmt, second_elec_roots)  
  push!(nodes, mngmt)
  push!(leaf_nodes, mngmt)
  id += 1 

  edge5 =  ElecEdge(mngmt, sub3, 0.0, elec_id)
  push!(mngmt.elec_edges, edge5)
  push!(sub3.elec_edges, edge5)
  push!(elec_edges, edge5)
  elec_id = elec_id + 1

  #now generate a different set of root nodes for the communication network (with different coordinates)
  com_root = Node(gateway, id,  x[id], y[id], 
              0, 0.0, Edge[], Edge[])
  push!(nodes, com_root)
  id += 1

  towers = Node[]
  #create the second level of nodes
  tow1 = Node(tower, id, x[id], y[id], 0, 0.0, Edge[], Edge[])
  push!(nodes, tow1)
  push!(towers, tow1)
  #generate the edge between root and tower
  #here we put the reliability of the edge to 1.0 because we assume that the infrastrucute is reliable
  cedge1 = ComEdge(com_root, tow1, 0.0, com_id, 1.0)
  push!(com_root.com_edges, cedge1)
  push!(tow1.com_edges, cedge1)
  push!(com_edges, cedge1)
  id += 1
  com_id += 1

  tow2 = Node(tower, id, x[id], y[id], 0, 0.0, Edge[], Edge[])
  push!(nodes, tow2)
  push!(towers, tow2)
  cedge2 = ComEdge(com_root, tow2, 0.0, com_id, 1.0)
  push!(com_root.com_edges, cedge2)
  push!(tow2.com_edges, cedge2)
  push!(com_edges, cedge2)
  id += 1
  com_id += 1
  #now connect all ders to the nearest towers 
  for n in leaf_nodes
    tow = min(n, towers)
    #generate the edge between tower and der
    edge = ComEdge(tow, n, 0.0, com_id, com_rel)
    push!(tow.com_edges, edge)
    push!(n.com_edges, edge)
    push!(com_edges, edge)  
    com_id += 1
  end

  return Network(nodes, elec_edges, com_edges) 
end

"helper function which generates the distributed energy resource node"
function generateDer(power, sd, id, x, y)
  return Node(der, id, x, y, power , sd,  Edge[], Edge[])
end