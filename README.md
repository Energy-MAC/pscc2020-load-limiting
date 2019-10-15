# Description
This repository provides the computational experiment to accompany the paper: Lee, Jonathan T., Anderson, Sean, Vergara, Claudio, and Callaway, Duncan. "Non-Intrusive Load Management Under Forecast Uncertainty in Energy Constrained Microgrids." *Electric Power Systems Research*, (Under Review).

# License
This code is made available under the BSD license. We request that any publications that use this code cite the paper above.

# Instructions
The code requires having MATLAB 2018A or higher and CVX version 2.1 installed with a Gurobi license (see http://cvxr.com/cvx/doc/gurobi.html).

At the start of a session, load the relevant directories to the MATLAB path by running `init.m`

See example scripts in the directory `scripts`. The file `runExperiments.m` runs the experiments referenced in the paper, but takes several hours or more. `runExperimentsSample.m` runs smaller example cases that takes minutes. `generateFigures.m` and `generateTables.m` creates the figures and tables used in the paper, respectively.

The foler `experiments` holds the class definitions of each experiment. `computation` holds the models of controllers, forecasts, microgrid, and the simulation.
