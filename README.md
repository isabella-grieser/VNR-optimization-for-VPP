# VNR optimization for VPP
This is the repository for my optimization project for the [EINS project seminar](https://www.eins.tu-darmstadt.de/eins/teaching/projektseminar-energieinformationssysteme) at TU Darmstadt.<br>
The main task of the project was to implement an mapping algorithm based on Mixed Integer Linear Programming to decide which and how many power generating units in a network are needed to satisfy a given minimum power output given the reliability of the different power units.<br>
The work begins with the generation of simple power generation models with corresponding communication models.
Furthermore, the project includes the formulation of mapping constraints and a throughout explanation of the assumptions and ideas for the calculation of the reliability of the total power output of the power units.
Finally, the project ends with an evaluation of the mapping algorithm and a comparison with less strict reliability constraint formulation shows that the project's algorithm leads to more redundant mapping of the power units, leading to a output that is more robust.<br>
The results of the project can be seen in the Notebook file.
