import matplotlib.pyplot as plt
import numpy as np

sun_path = "produkt_zehn_min_sonne_mannheim.txt"
wind_path = "produkt_zehn_min_wind_mannheim.txt"
# format: yyyymmdd
used_day = "20180709"
# import the data
sun_data_parsed = [l.split(';') for l in open(sun_path, "r").readlines()]
wind_data_parsed = [l.split(';') for l in open(wind_path, "r").readlines()]

# the data is for a whole year -> let us take the day 9.07 (no big reason for choosing this day)
# we only need the data from the rows 1 (time) and 3 (Globalstrahlung(intensity of the light that reaches the ground))
sun_data = [[line[1], line[4]] for line in sun_data_parsed if line[1].startswith(used_day)]
# for wind, we need the time and average wind speed
wind_data = [[line[1], line[3]] for line in wind_data_parsed if line[1].startswith(used_day)]
# remove the row titles
sun_data.pop(0)
wind_data.pop(0)


def rewrite_time(time):
    return '{}:{}'.format(time[-4:-2], time[-2:])


# rewrite the dates for later plotting
sun_data = [[rewrite_time(line[0]), float(line[1])] for line in sun_data]
wind_data = [[rewrite_time(line[0]), float(line[1])] for line in wind_data]

#fig, (ax1, ax2) = plt.subplots(1, 2)

x_labels = [l[0] for l in sun_data if l[0].endswith('00')]
x = [l[0] for l in sun_data]

# plot every 30 min
#plt.setp((ax1, ax2), xticks=range(11, len(sun_data), 24))

#ax1.plot(x, [l[1] for l in sun_data])
#ax1.set_title("sun irradiance")
#ax2.plot(x, [l[1] for l in wind_data])
#ax2.set_title("wind speed")
#plt.setp(ax1, ylabel='sunlight on ground in [J/cm^2]')
#plt.setp(ax2, ylabel='wind speed in [m/s]')
#plt.xlabel("time")
#plt.suptitle("sun irradiance and wind speed in Mannheim at 09/07/2018", fontsize=14)
#plt.show()


#solar panel efficiency
eff = 0.2
#time: 10 min in secs
time = 10*60
#air density
rho = 1.225
#wind turbine surface area
area = 11309
#factor
factor = 10**3
#now the plots for the average power output
#ax1.plot(x, [l[1]*eff*time/factor for l in sun_data])
#ax1.set_title("solar panel power generation")
#ax2.plot(x, [(rho*area*l[1]**3)/(2*factor) for l in wind_data])
#ax2.set_title("wind turbine power generation")
#plt.setp(ax1, ylabel='average power generation per square meter [kW/m^2]')
#plt.setp(ax2, ylabel='average power generation per unit [kW]')
#plt.setp(ax1, xlabel='time')
#plt.setp(ax2, xlabel='time')

amount = 100
#plot a pretty plot for the presentation
fig, ax1 = plt.subplots(1, 1)
plt.setp(ax1, xticks=range(11, len(sun_data), 24))
plt.plot(x, [(s[1]*eff*time*amount/factor+(rho*area*w[1]**3)/(2*factor))/5 for (s, w) in zip(sun_data, wind_data)], "r-")
plt.setp(ax1, ylabel='power output')
plt.setp(ax1, xlabel='time')
plt.show()