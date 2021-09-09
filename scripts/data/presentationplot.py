import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import norm

#just some simple plots for the presentation
mean = 50
variance = 30
x = np.arange(30,70,0.1)
f = np.exp(-np.square(x-mean)/(2*variance))/(np.sqrt(2*np.pi*variance))
#plt.plot(x, f, "r-")
#plt.xlabel("power output")
#plt.show()


size = np.arange(1, 10, 1)
levels = [3, 5, 7]
colors = ["r-", "y-", "b-"]
for (l,c) in zip(levels,colors):
    plt.plot(size, [l**s for s in size], c)

plt.legend(["|r_level|=3", "|r_level|=5", "|r_level|=7"])
plt.xlabel("number of nodes in the model")
plt.ylabel("number of scenarios")
plt.yscale("log")
plt.show()
