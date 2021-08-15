include("JuMPConstraints.jl")
include("modelGeneration.jl")
include("graphAnalysis.jl")
include("modelStructure.jl")

# format: yyyymmdd
used_day = "20180709"
#the load demand of the city
city_demand = 1196

#the percentage of solar panels and the percentage of wind turbines in the model
solar_percentage = .35
wind_percentage = .65

#for the model generation; the standard deviation of all power outputs of a specific der type
solar_sd = .05
wind_sd = .05

#model size parameters
clusters = 3
nodes_per_cluster = 2

#DER parameters 

#calculate the power generation for each producer type 
#solar panel efficiency
eff = 0.2
#air density
rho = 1.225
#wind turbine surface area
area = 11309
#sun panel size (one household = 36 m^2 -> we will work with a group of 10 households)
size = 36*10
#factor
factor = 10^6
#time
unit_time = 60*60

"""
calculates the vne for a specific model and a specific approach given the 
data of the city Mannheim; uses all approaches defined in the project
  
#arguments
- 'reliability' : the reliability of the vnr
- 'times' : the time that we want to analyse
- 'type' : the vne type that we want to use (currently available: "exact": the exact method of the project; 
"heuristic": the method where node scenario and link failure are independent; "simple": the method without the complex node scenarios)
- 'lambda, lambda_com_edge' : the unit price parameters for the model
- 'update' : if the model parameters (the DER values) need to be updated
- 'calculate_reliability' : if the reliability of the embedding needs to be calculated (based on the reliability
constraints of the exact model)
- 'scale' : the scale with which the power demand is divided with 
- 'vnr_value' : the power demand if we wish to use an specific value
"""
function dynamic_model_analysis(reliability = .95; model = nothing, times = 10, type = "exact", lambda = 2.0, lambda_com_edge = 2.0,
  update = false, calculate_reliability = false, scale = 1, vnr_value = 0, reliabilities = [0.3, 0.5, 0.7])

  #change directory to the data directory
  wind_vals = []
  open(pwd()*"\\data\\produkt_zehn_min_wind_mannheim.txt") do file
        for ln in readlines(file)
            spl = split(ln,";")
            if startswith(spl[2], used_day) && endswith(spl[2], "00")
              push!(wind_vals, (SubString(spl[2], 9, 10), parse(Float64,spl[4])))
            end
        end
    end
  sun_vals = []
  open(pwd()*"\\data\\produkt_zehn_min_sonne_mannheim.txt") do file
    for ln in readlines(file)
        spl = split(ln,";")
        if startswith(spl[2], used_day) && endswith(spl[2], "00")
          push!(sun_vals, (SubString(spl[2], 9, 10), parse(Float64,spl[5])))
        end
    end
end
  loads = []
  open(pwd()*"\\data\\duckcurve.txt") do file
    for ln in readlines(file)
      spl = split(ln,";")
      #ignore the value with the hour 24 (since the other ones do not have the value at the hour 24)
      if spl[1] != "24"
        push!(loads, (spl[1], parse(Float64,spl[2])))
      end
    end
  end

  #we need to modify the load amount so that its sum equals mannheim's daily demand  
  duck_demand = sum([l[2] for l in loads])
  multiplier = city_demand/duck_demand
  loads = [(l[1], l[2]*multiplier*10^9/factor) for l in loads]

  sun_vals = [(s[1], s[2]*eff*unit_time*size/factor) for s in sun_vals]
  wind_vals = [(w[1], (w[2]^3)*rho*area/(2*factor)) for w in wind_vals]

  #calculate the embedding for this iteration
#  for (i, l) in enumerate(loads)
#    #we already used the first value to generate the network
#    vnr = VNR(l[2], reliability)
#    model = update_model_parameters(model, sun_vals[i][2], wind_vals[i][2])
#    minimum_scenarios = create_minimum_scenarios(model.nodes, reliabilities, vnr.reliability)
#    calculate_embedding(model, vnr, reliabilities, minimum_scenarios, show_embedding = true, save = true, nr = "result_"*type*"_"*l[1])
#  end
  #I wanted to make a gif of all embeddings but it just does not want to work :(

   vnr = VNR(Float64(loads[times][2]/scale), reliability)
   if vnr_value != 0
    vnr = VNR(Float64(vnr_value), reliability)
   end

   if update 
    model = update_model_parameters(model, sun_vals[times][2], wind_vals[times][2])
   end

   minimum_scenarios = create_minimum_scenarios(model.nodes, model.com_edges, reliabilities, vnr.reliability)
   if calculate_reliability
    (r, tock)  = calculate_embedding(model, vnr, reliabilities, minimum_scenarios, type = type, 
    show_embedding = false, lambda = lambda, lambda_com_edge = lambda_com_edge, calculate_reliability = true) 
    return r, tock   
   else
    calculate_embedding(model, vnr, reliabilities, minimum_scenarios, type = type, 
    show_embedding = true, lambda = lambda, lambda_com_edge = lambda_com_edge)
   end
end

"""helper method to update the model parameters for each hour"""
function update_model_parameters(model, solar_mean, wind_mean)
  nodes = model.nodes
  for n in nodes
    if n.subtype == solar
      p = Int64(round(solar_mean - solar_sd*solar_mean + 2*solar_sd*solar_mean*randn(Float16)))
      n.power = (p<=0 || solar_mean == 0) ? 0 : p
    elseif n.subtype == wind
      p = Int64(round(wind_mean - wind_sd*wind_mean + 2*wind_sd*wind_mean*randn(Float16)))
      n.power = (p<=0) ? 0 : p
    end
  end
  return model
end


