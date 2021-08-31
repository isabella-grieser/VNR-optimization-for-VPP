import matplotlib.pyplot as plt
import numpy as np
from scipy.stats import norm

#just some simple plots for the presentation
mean = 50
variance = 30
x = np.arange(30,70,0.1)
f = np.exp(-np.square(x-mean)/(2*variance))/(np.sqrt(2*np.pi*variance))
plt.plot(x, f, "r-")
plt.xlabel("power output")
plt.show()
