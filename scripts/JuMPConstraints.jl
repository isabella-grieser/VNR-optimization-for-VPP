using JuMP, CPLEX

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")

function calculate_embedding(network, vnr, reliabilities, scenarios = []; show_failures = true
    , show_embedding = false)
    model = direct_model(CPLEX.Optimizer())
    
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

#for the link constraints we create a length(network.com_edges)xlength(ders) matrix to define each DER-VMO connections
@variable(model, y[i = 1:length(network.nodes), j = 1:length(network.nodes)], binary = true)
@constraint(model, sum(y[i,j] for i in 1:length(network.nodes)
                                            for j in 1:length(network.nodes)) >= 1)

#calculate the vnr links
# 1 = vmo, 2 = der
links = [[1,2]]
vnr_nodes = 2

@variable(model, x_float[u = 1:vnr_nodes, i = 1:length(network.nodes)])
@variable(model, y_float[uv = 1:length(links), i = 1:length(network.nodes), j = 1:length(network.nodes)])
#multi-commodity flow constraint
@constraint(model, c5[uv = 1:length(links), i = 1:length(network.nodes)],
           sum(y_float[uv,i,j] - y_float[uv,j,i] for j in get_neighboring_com_nodes_id(network.nodes[i])) 
            == sum(x_float[links[uv][1],i] - x_float[links[uv][2],i]))

#constraints for consistency between float and binary variables
#vmo
@constraint(model, c6[i = 1:length(network.nodes)], x_float[1, i] == x[1, i])
#ders
#here I subtract with the amount of nodes since the optimizer does not allow hard constraints
@constraint(model, c8[i = 1:length(network.nodes)], x_float[2, i] - x[2, i]*1/length(network.nodes) >= 0)
@constraint(model, c9[i = 1:length(network.nodes)], x[2, i] >= x_float[2, i])
#sn links; we need two constraints because y[i,j] >= abs(y_float[uv,i,j])
@constraint(model, c10[uv = 1:length(links), i = 1:length(network.nodes), j = 1:length(network.nodes)], 
            y[i,j] >= y_float[uv,i,j])
@constraint(model, c11[uv = 1:length(links), i = 1:length(network.nodes), j = 1:length(network.nodes)], 
            y[i,j] >= -y_float[uv,i,j])

    #scenario values; is an array of tuples(that define the power outputs in a specific scenario and the probability of the scenario)
    if isempty(scenarios)  
        scenarios = create_scenarios(network.nodes, reliabilities)
    end
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
    @constraint(model, c14[ h = 1:length(network.com_edges)], y_sum[h] >= y[c[h].from.id, c[h].to.id])
    @constraint(model, c15[h = 1:length(network.com_edges)], y_sum[h] >= y[c[h].to.id, c[h].from.id])
    #power unit costs for the ders
    lambda = 2.0
    lambda_com_edge = 2.0
    #objective function -> we aim to minimize this function
    @objective(model, Min, sum(x[2, i]*network.nodes[i].power*lambda for i in 1:length(network.nodes))
                        + sum(y_sum[i]*lambda_com_edge for i in 1:length(network.com_edges)))
    #to remove the annoying optimizer informations
    MOI.set(model, MOI.Silent(), true)
    optimize!(model)
        
    if show_failures
        display(value.(zeta))
    end
    print(raw_status(model))
    if show_embedding
        visualize_vnr(network, value.(x), value.(y_sum))
    end

end