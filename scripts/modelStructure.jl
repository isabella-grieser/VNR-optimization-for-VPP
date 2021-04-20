
#structs for network generation
"a power generating agent in a network that has specific coordinates"
struct Node{T<:Int32,V<:Float16}
    x::T
    y::T
    power::T
    reliability::V
    #comp_power::T
end
"a power distribution connection between two power generaing nodes"
struct ElecEdge{T<:Node}#,V<:Int32}
    from::T
    to::T
#    capacity::V
end
"a connection between two computing nodes"
struct ComEdge{T<:Node,V<:Int32}
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
