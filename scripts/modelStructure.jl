#abstract edge
#I only define this for circulary dependencies
abstract type Edge
end

#abstract node

#I differentiate the different nodes by this enum; I cant do this by struct since julia has no instanceof check :(
#pro: I can add new node types easier
@enum Nodetype begin
    #the root node of the electrical distribution network
    feeder
    #a substation for the electrical distribution network
    substation
    #the gateway. The root node of the communication network
    gateway 
    #a mobile communication tower
    tower
    #a power generating agent in a network that has specific coordinates
    der
    #the vpp management office
    management
    #the load
    load
end
#structs for network generation
mutable struct Node{P<:Nodetype,T<:Int64,V<:Float64,U<:Edge}
    type::P
    id::T
    x::T
    y::T
    power::T
    sd::V
    #do I even need the computing power?
    #comp_power::T
    elec_edges::Vector{U}
    com_edges::Vector{U}
end
"an electrical connection between two nodes"
struct ElecEdge{T<:Node, V<:Float64,U<:Int64}<:Edge
    from::T
    to::T
    cost::V
    id::U
    #capacity::V
end
"a connection between two computing nodes"
mutable struct ComEdge{T<:Node,V<:Float64,U<:Int64}<:Edge
    from::T
    to::T
    cost::V
    id::U
    reliability::V
    #do I need the bandwidth
    #bandwidth::V
end
"the general electrical distribution network"
struct Network{T<:Node,V<:ElecEdge,Z<:ComEdge}
    nodes::Vector{T}    
    elec_edges::Vector{V}
    com_edges::Vector{Z}
end

struct VNR{T<:Int64,V<:Float64}
    power::T
    reliability::V
end