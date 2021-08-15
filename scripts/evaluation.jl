import CSV, Plots, DataFrames

include("dynamicModelAnalysis.jl")

#all defined approaches in the project
approaches = ["exact" , "heuristic" ,"simple" , "no_link_failure"]

plt = Plots
#the max amount of loops; needs to  be at least 2!!!!!(for the calculation of the standard deviation)
loops = 10

#model size parameters
max_clusters = 6
max_nodes_per_cluster = 1

#the time that we will use in our evaluation
used_time = 10
#the price used for our example
unit_price = .3

save = true
#when saving -> save name
name = "test"

#min scale of the power output
min_scale = 1.5
scale_increase = 1.5

"""calculates the evaluation based on the global parameters defined in this file"""
function make_evaluation()
    #the time used for the approaches
    times = zeros(length(approaches), loops, max_clusters*max_nodes_per_cluster)
    #the reliability of the approaches
    rel = zeros(length(approaches), loops, max_clusters*max_nodes_per_cluster)

    used_scale = min_scale
    for c in 1:max_clusters
        for n in 1:max_nodes_per_cluster
        #generate a new model for each iteration
        used_model = generate_network(c, n)
            for i in 1:loops
                for (index, a) in enumerate(approaches)
                    r = nothing
                    tock = 0
                    first_iter = 0
                    #I saw when evaluating that the first calculation really skews the time measurement
                    # -> ignore the first calculation
                    while r === nothing || r < 0 || (first_iter == 0 && c == 1 && n == 1 && index == 1 && i == 1)               
                        r, tock = dynamic_model_analysis(.90, model = used_model, times = used_time, type = a, 
                        lambda = unit_price, update = true, calculate_reliability = true, vnr_value = used_scale)                     
                        #if an embedding cannot be found -> generate a new model where an embedding hopefully can be found
                        if  r === nothing || r < 0
                            used_model = generate_network(c, n) 
                            print("nothing: size:"*string(c*n)*", approach:"*a*"\n")  
                        end 
                        first_iter += 1          
                    end
                    times[index, i, c*n] = tock
                    rel[index, i, c*n] = r
                end
            end
            used_scale += scale_increase
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

    #plotting functions
    #subplots for the time means and variance
    p1 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [time_means[1,i] for i in 1:(max_clusters*max_nodes_per_cluster)],
    ribbon=[time_var[1,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  label = ["exact"])

    p2 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [time_means[2,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[time_var[2,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["heuristic"])

    p3 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [time_means[3,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[time_var[3,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["simple"])

    p4 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [time_means[4,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[time_var[4,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["no link failure"])
        
    plt.plot(p1, p2, p3, p4,layout =(2,2))
    if save
        plt.savefig(pwd()*"\\fig\\time"*name*string(clusters)*string(nodes_per_cluster)*".png")
    end
    #subplot for the reliability mean and variance
    p1 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [rel_means[1,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[rel_var[1,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["exact"])

    p2 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [rel_means[2,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[rel_var[2,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["heuristic"])

    p3 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [rel_means[3,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[rel_var[3,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["simple"])

    p4 = plt.plot([i for i in 1:(max_clusters*max_nodes_per_cluster)], 
    [rel_means[4,i] for i in 1:(max_clusters*max_nodes_per_cluster)],  
    ribbon=[rel_var[4,i] for i in 1:(max_clusters*max_nodes_per_cluster)], label = ["no link failure"])

    plt.plot(p1, p2, p3, p4,layout =(2,2))
    if save
        plt.savefig(pwd()*"\\fig\\reliability"*name*string(clusters)*string(nodes_per_cluster)*".png")        
    end

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
    CSV.write(pwd()*"\\eval\\results.csv", t_save, delim=';')      
end


#do the evaluation
make_evaluation()