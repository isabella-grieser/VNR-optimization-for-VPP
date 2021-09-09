using JuMP, Gurobi, Printf

include("modelGeneration.jl")
include("modelStructure.jl")
include("graphAnalysis.jl")
"""
calculates the embedding using the constraints defined in the notebook 
  
#arguments
- 'reliability' : the reliability of the vnr
- 'times' : the time that we want to analyse
- 'type' : the vne type that we want to use (currently available: "exact": the exact method of the project; 
"heuristic": the method where node scenario and link failure are independent; "simple": the method without the complex node scenarios)
- 'lambda, lambda_com_edge' : the unit price parameters for the model
- 'update' : if the model parameters (the DER values) need to be updated
- 'calculate_reliability' : if the reliability of the embedding needs to be calculated (based on the reliability
constraints of the exact model)
"""
function calculate_embedding(network, vnr, reliabilities, scenario_outputs = []; show_failures = false, 
    show_embedding = false, type = "exact", lambda = 2.0, lambda_com_edge = 2.0, save = false, nr = "1",
    calculate_reliability = false)

tick = time()
model = direct_model(Gurobi.Optimizer())
m = backend(model)

#the activation of the nodes, all defined as binary vectors
#the first x is the vmo node, the second x are the DER nodes
@variable(model, x[1:2, 1:length(network.nodes)], binary = true) 

#mapping constraints
# 1 = vmo, 2 = der
@constraint(model, c1, sum(x[1, i] for i in 1:length(network.nodes)) == 1)
@constraint(model, c2, sum(x[2, i] for i in 1:length(network.nodes)) >= 1)

#now we define that the vmo node must be mapped to the specific substrate vmo
#vmo constraint; the vmo should be on (x,y) = (1,1)
@constraint(model, c3[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].x)
@constraint(model, c4[i = 1:length(network.nodes)], x[1, i] <= 1/network.nodes[i].y)


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

#constraints for consistency between float and binary node variables
#vmo -> no complex constraint necessary, since the floating point value is always 1
@constraint(model, c6[i = 1:length(network.nodes)], x_float[1, i] == x[1, i])
#ders
#translation from binary to floatin point variables
@constraint(model, c8[i = 1:length(network.nodes)], x_float[2, i] - x[2, i]*1/length(network.nodes) >= 0)

@variable(model, y[h = 1:length(network.com_edges)], binary = true)

c = network.com_edges

#sn links; we need four constraints because y[l] >= abs(y_float[uv,l.from,l.to]) and y[l] >= abs(y_float[uv,l.to,l.from])
@constraint(model, c9[uv = 1:length(links), l = 1:length(network.com_edges)], 
            y[l] >= y_float[uv,c[l].from.id,c[l].to.id])
@constraint(model, c10[uv = 1:length(links), l = 1:length(network.com_edges)], 
            y[l] >= -y_float[uv,c[l].from.id,c[l].to.id])

@constraint(model, c11[uv = 1:length(links), l = 1:length(network.com_edges)], 
            y[l] >= y_float[uv,c[l].to.id,c[l].from.id])
@constraint(model, c12[uv = 1:length(links), l = 1:length(network.com_edges)], 
            y[l] >= -y_float[uv,c[l].to.id,c[l].from.id])




#now begin the scenario constraints 

if type == "exact"
#scenario values; is an array of tuples(that define the power outputs in a specific scenario and the probability of the scenario)
if isempty(scenario_outputs)  
    scenario_outputs = create_scenarios(network.nodes, reliabilities)
end

#scenario variables 
@variable(model,zeta[1:length(scenario_outputs), 1:(length(network.com_edges)+1)], binary = true)
@variable(model,epsilon[1:(length(network.com_edges)+1), 1:length(network.nodes)], binary = true)

#calculate the link reliability
@constraint(model, c13[i = 1:length(network.nodes), l = 1:length(network.com_edges); 
                        i in get_dependent_nodes(network.com_edges[l])], epsilon[l, i] == 0)
@constraint(model, c14[i = 1:length(network.nodes)], epsilon[length(network.com_edges)+1, i] == 1)

@constraint(model, c15[i = 1:length(scenario_outputs), l = 1:(length(network.com_edges)+1)], zeta[i, l]*vnr.power
        + sum(x[2,n]*scenario_outputs[i][2][n]*epsilon[l, n] for n in 1:length(network.nodes)) >= vnr.power)

#probability variables
#use the sum of all probabilities, not of the reduced size of probabilities
all_scenarios = create_scenarios(network.nodes, reliabilities)
sum_pi = sum(all_scenarios[i][1]*(1-network.com_edges[l].reliability)
        for i in 1:length(all_scenarios) for l in 1:length(network.com_edges))
sum_pi += sum((s)->s[1], all_scenarios)

#scenario node constraint; go over all scenarios and check if the power constraint is solved 
@constraint(model, c16, (1/sum_pi)*(sum(zeta[i, l]*scenario_outputs[i][1]*(1-network.com_edges[l].reliability)
        for i in 1:length(scenario_outputs) for l in 1:length(network.com_edges)) 
        + sum(zeta[i, length(network.com_edges)+1]*scenario_outputs[i][1]
        for i in 1:length(scenario_outputs)))<= 1.0-vnr.reliability)

elseif type == "heuristic"

@variable(model,epsilon[1:length(network.com_edges), 1:length(network.nodes)], binary = true)
#scenario variables 
@variable(model,zeta[1:length(scenario_outputs)], binary = true)
@variable(model,zeta_link[1:length(network.com_edges)], binary = true)

#normalization factor again
all_scenarios = create_scenarios(network.nodes, reliabilities)
sum_pi = sum((s)->s[1], all_scenarios)
#then, add the new constraints
#node constraints
@constraint(model, c14[i = 1:length(scenario_outputs)], zeta[i]*vnr.power 
    + sum(x[2,n]*scenario_outputs[i][2][n] for n in 1:length(network.nodes)) >= vnr.power)

@constraint(model, c15, (1/sum_pi)*(sum(zeta[i]*scenario_outputs[i][1] for i in 1:length(scenario_outputs))) 
                    <= 1.0-vnr.reliability)

#link constraints
sum_link = sum((l)->(1-l.reliability), network.com_edges)
@constraint(model, c16[l = 1:length(network.com_edges)], zeta_link[l]*vnr.power
        + sum(x[2,n]*network.nodes[n].power*epsilon[l, n] for n in 1:length(network.nodes)) >= vnr.power)

@constraint(model, c17, (1/sum_link)*sum(zeta_link[l]*(1-network.com_edges[l].reliability)
                            for l in 1:length(network.com_edges)) <= 1.0-vnr.reliability)
elseif type == "simple"
@variable(model,epsilon[1:(length(network.com_edges)+1), 1:length(network.nodes)], binary = true)
@variable(model,zeta_link[1:length(network.com_edges)], binary = true)   
#node constraints
@constraint(model, c14, sum(x[2,n]*network.nodes[n].power for n in 1:length(network.nodes)) >= vnr.power)

#link constraints
@constraint(model, c15[l = 1:length(network.com_edges)], zeta_link[l]*vnr.power
        + sum(x[2,n]*network.nodes[n].power*epsilon[l, n] for n in 1:length(network.nodes)) >= vnr.power)

sum_link = sum((l)->(1-l.reliability), network.com_edges)
@constraint(model, c16, (1/sum_link)*sum(zeta_link[l]*(1-network.com_edges[l].reliability)
                            for l in 1:length(network.com_edges)) <= 1.0-vnr.reliability)
elseif type == "no_link_failure"
#node constraints
@constraint(model, c14, sum(x[2,n]*network.nodes[n].power for n in 1:length(network.nodes)) >= vnr.power)
end


#objective function -> we aim to minimize this function
@objective(model, Min, sum(x[2, i]*network.nodes[i].power*lambda for i in 1:length(network.nodes))
                       + sum(y[i]*lambda_com_edge for i in 1:length(network.com_edges)))
    

MOI.set(model, MOI.Silent(), true)
optimize!(model)

tock = time() - tick 
if show_failures
    display(value.(zeta))
end

if calculate_reliability
    #calculate the reliability based on the reliability calculation of the exact model
    if termination_status(model) != MOI.OPTIMAL
        return nothing, tock
    else
        #working with values.(x) does not work directly (no idea why) -> create a variable x
        #Im stupid and used values.(x) instead of value.(x)
        x = [i for i in value.(x)[2,:]]

        scen = create_scenarios(network.nodes, reliabilities)
        sum_pi = sum(scen[i][1]*(1-network.com_edges[l].reliability)
        for i in 1:length(scen) for l in 1:length(network.com_edges))
        sum_pi += sum((s)->s[1], scen)

        #calculate zeta and epsilon for all approaches based on the active nodes
        z = zeros(length(scenario_outputs), (length(network.com_edges)+1))
        e = zeros((length(network.com_edges)+1), length(network.nodes))
        for n in network.nodes
            for l in network.com_edges
                if n.id in get_dependent_nodes(l)
                    e[l.id, n.id] = 0
                else
                    e[l.id, n.id] = 1
                end
            end
            e[length(network.com_edges)+1, n.id] = 1
        end
        for (i,v) in enumerate(scenario_outputs)
            for l in network.com_edges
                power_sum = sum([x[n]*v[2][n]*e[l.id, n] 
                    for n in 1:length(network.nodes)])
                if  power_sum < vnr.power
                    z[i, l.id] = 1
                else
                    z[i, l.id] = 0
                end
            end
            power_sum = sum(x[n]*v[2][n]*e[length(network.com_edges)+1, n] 
            for n in 1:length(network.nodes))
            if (power_sum < vnr.power)
                z[i, length(network.com_edges)+1] = 1
            else
                z[i, length(network.com_edges)+1] = 0
            end
        end

        #check how many nodes are activated
        print("activated nodes:"*string(sum(x))*"; ") 
        #now calculate the reliability
        failure = (1/sum_pi)*((sum(z[i, l]*scenario_outputs[i][1]*(1-network.com_edges[l].reliability)
        for i in 1:length(scenario_outputs) for l in 1:length(network.com_edges)) 
        + sum(z[i, length(network.com_edges)+1]*scenario_outputs[i][1]
        for i in 1:length(scenario_outputs))))

        return (1 - failure), tock
    end   
end

if show_embedding
    (minutes, seconds) = fldmod(tock, 60)
    (hours, minutes) = fldmod(minutes, 60)

    @printf("calculation time: %02d:%02d:%0.2f", hours, minutes, seconds)
    if termination_status(model) != MOI.OPTIMAL
        @printf("optimal solution could not be found")
        #visualize_vnr(network, zeros(Int32, 2, length(network.nodes)), zeros(Int32, 1, length(network.com_edges)), save = save, nr = nr)         
    else
        visualize_vnr(network, value.(x), value.(y), save = save, name = nr)        
    end
else 
    if termination_status(model) != MOI.OPTIMAL
        print("no solution could be found for the model")
    else
        print("problem has optimal solution")
    end
end
end