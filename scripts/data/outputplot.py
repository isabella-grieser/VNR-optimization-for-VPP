import matplotlib.pyplot as plt

path = "duckcurve.txt"

#the data was manually written from https://www.iea.org/data-and-statistics/charts/the-california-duck-curve
#because I didnt find the source
#its in mw
parsed_dataset = [l.split(";") for l in open(path, "r").readlines()]

time = [float(arr[0]) for arr in parsed_dataset]
output = [float(arr[1]) for arr in parsed_dataset]

#in MW
avg_output = 1196

#I change the output so that the sum is equal to the avg_output

output_value = sum(output)

multiplier = avg_output/output_value

output = [o*multiplier for o in output]

time = ['{}:00'.format(int(t)) for t in time]


plt.xticks(range(1, len(time), 4))
plt.plot(time, output)
plt.xlabel("time")
plt.ylabel("total load [MW]")
plt.title("estimated total load of the city Mannheim at 09/07/2018")
plt.show()