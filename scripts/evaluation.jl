import CSV, Plots, DataFrames, PyPlot

include("dynamicModelAnalysis.jl")

#all defined approaches in the project
approaches = ["exact" , "heuristic" ,"simple" , "no_link_failure"]

plt = Plots
#the max amount of loops; needs to  be at least 2!!!!!(for the calculation of the standard deviation)
loops = 15

#model size parameters
max_clusters = 7
max_nodes_per_cluster = 1

min_clusters = 2
min_nodes_per_cluster = 1

#the time that we will use in our evaluation
used_time = 15
#the price used for our example
unit_price = .3

extra_name = "high_reliability"
save = true

#scale of the power output
eval_reliabilities = [0.4, 0.5, 0.6]
power_scale = .2
rl = .95

"""calculates the evaluation based on the global parameters defined in this file"""
function make_evaluation()
    #the time used for the approaches
    times = zeros(length(approaches), loops, max_clusters*max_nodes_per_cluster)
    #the reliability of the approaches
    rel = zeros(length(approaches), loops, max_clusters*max_nodes_per_cluster)

    for c in min_clusters:max_clusters
        for n in min_nodes_per_cluster:max_nodes_per_cluster
        #generate a new model for each iteration
        used_model = generate_network(c, n)
        #calculate the power output that we want to have for the vnr
            for i in 1:loops
                for (index, a) in enumerate(approaches)
                    r = nothing
                    tock = 0
                    first_iter = 0
                    #I saw when evaluating that the first calculation really skews the time measurement
                    # -> ignore the first calculations
                    while r === nothing || r < 0 || (first_iter < 2 && c == min_clusters && n == min_nodes_per_cluster) 
                        tick = time()              
                        r, tock = dynamic_model_analysis(rl, model = used_model, times = used_time, type = a, 
                        lambda = unit_price, update = true, calculate_reliability = true,  vnr_value = true,
                        reliabilities = eval_reliabilities, power_scale = power_scale)                     
                        #if an embedding cannot be found -> generate a new model where an embedding hopefully can be found
                        print("size:"*string(c*n)*"; ")
                        first_iter += 1 
                        #tock = time()-tick   
                        if r === nothing || r < 0
                            print("try again; ")
                            used_model = generate_network(c, n)
                        end      
                    end                 
                    times[index, i, c*n] = tock
                    rel[index, i, c*n] = r
                end
            end
        end
    end

    #calculate the mean values for each model size
    time_means = zeros(length(approaches), max_clusters*max_nodes_per_cluster)
    rel_means = zeros(length(approaches), max_clusters*max_nodes_per_cluster)

    for (index, a) in enumerate(approaches)
        for c in 1:max_clusters
            for n in 1:max_nodes_per_cluster
                #get the values over all iterations
                iter_values = [times[index, i, c*n] for i in 1:loops]
                #calculate the mean
                time_means[index, c*n] = (1/length(iter_values))*sum(iter_values)

                iter_values = [rel[index, i, c*n] for i in 1:loops]
                rel_means[index, c*n] = (1/length(iter_values))*sum(iter_values)
            end
        end
    end

    #now calculate the variance for each model size
    time_var = zeros(length(approaches), max_clusters*max_nodes_per_cluster)
    rel_var = zeros(length(approaches), max_clusters*max_nodes_per_cluster)

    for (index, a) in enumerate(approaches)
        for c in 1:max_clusters
            for n in 1:max_nodes_per_cluster
                #get the values over all iterations again
                iter_values = [times[index, i, c*n] for i in 1:loops]
                #calculate the variance
                time_var[index, c*n] = (1/(length(iter_values)-1))*sum([(i
                                        -time_means[index, c*n])^2 for i in iter_values])

                iter_values = [rel[index, i, c*n] for i in 1:loops]
                rel_var[index, c*n] = (1/(length(iter_values)-1))*sum([(i
                                        -rel_means[index, c*n])^2 for i in iter_values])
            end
        end
    end
    time_max = maximum([time_means[a,i] for a in 1:length(approaches) 
                    for i in (min_clusters*min_nodes_per_cluster):(max_clusters*max_nodes_per_cluster)])

    #plotting in julia is a nightmare
    
    plot_values = [i for i in (min_clusters*min_nodes_per_cluster):(max_clusters*max_nodes_per_cluster)]

    #time plot
    fig = PyPlot.figure(figsize=(14, 4))
    PyPlot.subplot(121)
    PyPlot.grid("on")
    PyPlot.legend(loc="upper right")
    plot_with_variance(plot_values, time_means[1,:],time_var[1,:] ,"lightcoral", "r", true)
    plot_with_variance(plot_values, time_means[2,:],time_var[2,:] ,"cornsilk", "y", true)
    plot_with_variance(plot_values, time_means[3,:],time_var[3,:] ,"aqua", "b", true)
    plot_with_variance(plot_values, time_means[4,:],time_var[4,:] ,"lightgray", "k", true)
    PyPlot.title("Time")
    PyPlot.ylabel("solving time in ms")
    PyPlot.xlabel("number of nodes in the model")
    PyPlot.yscale("log")
    PyPlot.legend(approaches)

    #reliability plot
    PyPlot.subplot(122)
    PyPlot.grid("on")
    PyPlot.legend(loc="upper right")
    plot_with_variance(plot_values, rel_means[1,:],rel_var[1,:] ,"lightcoral", "r", false)
    plot_with_variance(plot_values, rel_means[2,:],rel_var[2,:] ,"cornsilk", "y", false)
    plot_with_variance(plot_values, rel_means[3,:],rel_var[3,:] ,"aqua", "b", false)
    plot_with_variance(plot_values, rel_means[4,:],rel_var[4,:] ,"lightgray", "k", false)
    #plot to generate a constant for reliability
    plot_with_variance(plot_values,[rl for i in rel_means[4,:]],[0 for i in rel_means[4,:]],"purple", "m", true)
    PyPlot.title("Reliability")
    PyPlot.ylabel("reliability")
    PyPlot.xlabel("number of nodes in the model")
    legs = []

    for a in approaches
    push!(legs, a)        
    end

    push!(legs, "r_vpp")
    PyPlot.legend(legs)
    fig.canvas.draw()
    PyPlot.savefig(pwd()*"\\fig\\eval"*string(eval_reliabilities[1])*extra_name*".png")
    #save the values as a csv file
    frame = DataFrames

    t_save = frame.DataFrame(Approach = [a for a in approaches for i in 1:(max_clusters*max_nodes_per_cluster)], 
        ModelSize = [i for a in approaches for i in 1:(max_clusters*max_nodes_per_cluster)], 
        MeanTime = [time_means[a,i] for a in 1:length(approaches) 
                    for i in 1:(max_clusters*max_nodes_per_cluster)],
        MeanVar =  [time_var[a,i] for a in 1:length(approaches) 
                    for i in 1:(max_clusters*max_nodes_per_cluster)],
        RelTime = [rel_means[a,i] for a in 1:length(approaches) 
                    for i in 1:(max_clusters*max_nodes_per_cluster)],
        RelVar =  [rel_var[a,i] for a in 1:length(approaches) 
                    for i in 1:(max_clusters*max_nodes_per_cluster)])
    CSV.write(pwd()*"\\eval\\results"*string(eval_reliabilities[1])*extra_name*".csv", t_save, delim=';')      
end

#small function to plot the values with its variance 
function plot_with_variance(plot_values, means, var, var_color, plot_color, islog)
    sigmapos = [means[i]+var[i] for i in plot_values]
    sigmaneg = [(means[i]-var[i] > 0) ? means[i]-var[i] : 0 for i in plot_values]
    if !islog
        #I dont understand but the log things are not working again :(
        PyPlot.fill_between(plot_values, sigmapos, sigmaneg, color=var_color)
    end
    PyPlot.plot(plot_values, [means[i] for i in plot_values], plot_color*"-")

end

#do the evaluation
make_evaluation()