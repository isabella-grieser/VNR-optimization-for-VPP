
#abstract edge
#I only define this for circulary dependencies
abstract type Edge
end
#structs for network generation
"a power generating agent in a network that has specific coordinates"
mutable struct Node{T<:Int64,V<:Float16,U<:Edge}
    x::T
    y::T
    power::T
    reliability::V
    #comp_power::T
    id::T
    elec_edges::Vector{U}
    com_edges::Vector{U}
end
"a power distribution connection between two power generaing nodes"
struct ElecEdge{T<:Node}<:Edge#,V<:Int32}
    from::T
    to::T
    #capacity::V
end
"a connection between two computing nodes"
struct ComEdge{T<:Node,V<:Int32}<:Edge
    from::T
    to::T
    bandwidth::V
end
"the general electrical distribution network"
struct Network{T<:Node,V<:ElecEdge,Z<:ComEdge}
    nodes::Vector{T}    
    elec_edges::Vector{V}
    com_edges::Vector{Z}
end
