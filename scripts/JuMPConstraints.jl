using JuMP, CPLEX

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")

function calculate_embedding(network, vnr, reliabilities)
    model = direct_model(CPLEX.Optimizer())
    #get the indexes of all ders in the model
    ders = filter(n -> n.type == der, network.nodes)
    
    #the activation of the nodes, all defined as binary vectors
    #the first x is the vmo node, the second x are the DER nodes
    @variable(model, x[1:2, 1:length(network.nodes)], binary = true) 



    #mapping constraints
    @constraint(model, c1, sum(x[1, i] for i in 1:length(network.nodes)) == 1)
    @constraint(model, c2, sum(x[2, i] for i in 1:length(network.nodes)) >= 1)

    #now we define that the vmo node must be mapped to the specific substrate vmo
    #vmo constraint; the vmo should be on (x,y) = (1,1)
    @constraint(model, c3[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].x)
    @constraint(model, c4[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].y)

    #extra condition: only nodes with a power>0 can be used to map the virtual DER; else the optimizer will just activate all nodes
    @constraint(model, c7[i = 1:length(network.nodes)], x[2, i] => {network.nodes[i].power >= 1})

    #for the link constraints we create a length(network.com_edges)xlength(ders) matrix to define each DER-VMO connections
    @variable(model, y[uvs = 1:length(ders), i = 1:length(network.nodes), j = 1:length(network.nodes)], binary = true)
    @constraint(model, c8[uvs = 1:length(ders)], sum(y[uvs,i,j] for i in 1:length(network.nodes)
                                                for j in 1:length(network.nodes)) >= 1)

    #this variable defines for each virtual (u,v)-link which node is u (the vmo is always v)
    @variable(model, u[uv = 1:length(ders), j = 1:length(network.nodes)], binary = true)
    @constraint(model, c9[uv = 1:length(ders)], u[uv, ders[uv].id] == x[2, ders[uv].id])
    #@constraint(model, c10[uv = 1:length(ders), j = 1:length(network.nodes); ders[uv].id != j], u[uv, j] == 0)

    @variable(model, v[i = 1:length(ders), j = 1:length(network.nodes)], binary = true)
    #v is 1 if for the possible uvs link u is one and it is the vmo node
    @constraint(model, [uv = 1:length(ders), j = 1:length(network.nodes)], v[uv, j] <= x[1, j])
    @constraint(model, [uv = 1:length(ders), j = 1:length(network.nodes)], v[uv, j] <= u[uv, ders[uv].id])
    @constraint(model, [uv = 1:length(ders), j = 1:length(network.nodes)], v[uv, j] >= x[1, j] + u[uv, ders[uv].id] - 1)


    #multi-commodity flow constraint, u are the ders, v is the vmo
    @constraint(model, c11[uv = 1:length(ders),i = 1:length(network.nodes)],
            sum((y[uv,i,j] - y[uv,j,i]) for j in get_neighboring_com_nodes_id(network.nodes[i])) == (u[uv, i] - v[uv, i]))


    #scenario values; is an array of tuples(that define the power outputs in a specific scenario and the probability of the scenario)
    scenario_outputs = create_scenarios(network.nodes, reliabilities)
    #scenario variables 
    @variable(model,zeta[1:length(scenario_outputs)], binary = true)

    #scenario node constraint; go over all scenarios and check if the power constraint is solved 
    @constraint(model, c12[i = 1:length(scenario_outputs)], zeta[i]*vnr.power 
        + sum(x[2,n]*scenario_outputs[i][2][n] for n in 1:length(network.nodes)) >= vnr.power)

    #calculate the reliability
    @constraint(model, c13, sum(zeta[i]*scenario_outputs[i][1] for i in 1:length(scenario_outputs)) <= 1.0-vnr.reliability)

    #link summary constraint
    @variable(model, y_sum[1:length(network.com_edges)], binary = true) 

    c = network.com_edges
    #these constraints summarize the link activations for easier calculation; 
    #If a link was activated on any virtual link, then the link is activated on the vnr
    @constraint(model, c14[uvs = 1:length(ders), h = 1:length(network.com_edges)], y_sum[h] >= y[uvs, c[h].from.id, c[h].to.id])
    @constraint(model, c15[uvs = 1:length(ders), h = 1:length(network.com_edges)], y_sum[h] >= y[uvs, c[h].to.id, c[h].from.id])
    #power unit costs for the ders
    lambda = 2.0
    lambda_com_edge = 2.0
    #objective function -> we aim to minimize this function
    @objective(model, Min, sum(x[2, i]*network.nodes[i].power*lambda for i in 1:length(network.nodes))
                        + sum(y_sum[i]*lambda_com_edge for i in 1:length(network.com_edges)))

    optimize!(model)

    #get the results of the optimization
    #objective_value(model)
    
    display(value.(zeta))
#    display(value.(x))
#    display(c12)
#    display(c13)
    visualize_vnr(network, value.(x), value.(y_sum))
end