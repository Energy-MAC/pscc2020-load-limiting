# Description
This repository provides the computational experiments to accompany the paper: Lee, Jonathan T., Anderson, Sean, Vergara, Claudio, and Callaway, Duncan. "[Non-Intrusive Load Management Under Forecast Uncertainty in Energy Constrained Microgrids](http://pscc.epfl.ch/rms/modules/request.php?module=oc_program&action=summary.php&id=453)." *Electric Power Systems Research*, (In Press).

# License
This code is made available under the MIT license. We request that any publications that use this code or follow the methodology therein cite the paper above. Please contact Jonathan Lee by email at jtlee@berkeley.edu or through Github if you have difficulty accessing a copy of the paper.

# Instructions
Please use the Github issue tracker to post any problems encountered using the project, and we will address them.
## Dependencies
The code requires having MATLAB 2018A or higher. The full functionality also requires having [Gurobi 9.0 installed with a license and configured for use in MATLAB](https://www.gurobi.com/documentation/9.0/quickstart_mac/matlab_setting_up_grb_for_.html). Earlier versions used CVX version 2.1 in development, but the latest version does not depend on CVX.

Please be advised that this repository includes more than 1 GB of data from simulation results associated with the paper so cloning may take some time.

This repository depends heavily upon [microgrid-dispatch-simulator](https://github.com/leejt489/microgrid-dispatch-simulator) for simulation and upon [computational-experiment-matlab](https://github.com/leejt489/computational-experiment-matlab) for the design of computational experiments. The specific branches of these projects are included here as sub-repositories. Note that to clone these, you need to clone with `git clone --recurse-submodules`.

## Usage and Reproducibility
Be sure to use `git clone --recurse-submodules` when cloning to include the microgrid dispatch simulator and computational experiment projects, i.e. "git clone --recurse-submodules https://github.com/Energy-MAC/pscc2020-load-limiting".

At the start of a session, load the relevant directories to the MATLAB path by running `init.m`.

### Executing an experiment
The main entry point to run an experiment is [bin/runExperiment.m](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/bin/runExperiment.m). As an example, run:
```
runExperiment('controllerPerformance','sample')
```
This will execute a reduced experiment used in the paper, but with only 10 trials, which should complete in a couple of minutes. The full experiment is run with `runExperiment('controllerPerformance')`, which will likely take multiple days.

To execute both the performance and timing experiments, and reproduce the paper results you can run [scripts/runExperimentsPaper.m](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/scripts/runExperimentsPaper.m). To run a reduced sample, you can run [scripts/runExperimentsSample.m](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/scripts/runExperimentsSample.m).

To improve performance and execute experiments standalone, you can build an executable `runExperiment.exe` using the script `build.m`. This requires the MATLAB `mcc` compiler.

### Analyzing results
This repository includes the output data used in the paper. Reproduce the figures in the paper with [scripts/generatePaperFigures](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/scripts/generatePaperFigures.m). This will write new figures into the `figures` directory.

## Architecture
This repository provides the computational experiments to accompany the above paper, and also serves as an example usage of [microgrid-dispatch-simulator](https://github.com/leejt489/microgrid-dispatch-simulator) and [computational-experiment-matlab](https://github.com/leejt489/computational-experiment-matlab), with the caveat that this repository uses specific versions of these projects.

For context on the principles used in creating these experiments and the terminology used in describing them, we recommend reviewing the methodological paper: Lara, José Daniel, Lee, Jonathan T., Callaway, Duncan, and Hodge, Bri-Matthias. "[Computational Experiment Design for Operations Model Simulation](http://pscc.epfl.ch/rms/modules/request.php?module=oc_program&action=summary.php&id=527)." *Electric Power Systems Research*, (In Press). This repository provides specific instances of computational experiments in the directory `experiments` which inherit from the abstract experiment defined in [computational-experiment-matlab](https://github.com/leejt489/computational-experiment-matlab). In the terminolgy of the experiment design paper, [microgrid-dispatch-simulator](https://github.com/leejt489/microgrid-dispatch-simulator) for simulation and upon [computational-experiment-matlab](https://github.com/leejt489/computational-experiment-matlab) provides the "emulator model". For details on this model, please refer to the Non-Intrusive Load Management paper and [the microgrid-dispatch-simulator README](https://github.com/leejt489/microgrid-dispatch-simulator/tree/2953f41f9dd324aa081e29faf608ba104061e800).

The experiment [ControllerPerformanceExperiment.m](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/experiments/ControllerPerformanceExperiment.m) *declares* the experiment workflow, which includes the data process, the simulation process, and the results and reporting process.

The `Experiment` superclass from [computational-experiment-matlab](https://github.com/leejt489/computational-experiment-matlab) *executes* the workflow by calling these methods in loops, performing the iterations over trials, saving output data, managing the random number generator, etc.

### Data Process
The raw data used to define the experiments are defined in `.csv` files in the `data` directory.

Specific data for each type of experiment are defined in `data/experiments/inputs/[experimentName]`. In this case, there are two experiments `ControllerPerformance` and `ComputationTime`, and thus a directory for each. Each of these experiments has a default instance, or a `case`. Cases are used to run the same experiment workflow, but with different input data. The cases given here are `sample`, whose purpose is to provide an example with a reduced number of trials and shorter simulations that will run quickly, and `test`, which is even more reduced for the purposes of testing. So, for the `ControllerPerformance` experiment, the main *experiment parameters* for the default case are defined in [data/experiments/inputs/controllerPerformance/key_values.csv](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/data/experiments/inputs/controllerPerformance/key_values.csv). For the sample case, they are defined in [data/experiments/inputs/controllerPerformance/sample/key_values.csv](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/data/experiments/inputs/controllerPerformance/sample/key_values.csv). Additional experiment parameters, which are in list format, are defined in separate `.csv` files. In this case, the only ones are in the `controllers.csv` file, which simply defines the names of the controllers to compare as independent variables ([data/experiments/inputs/controllerPerformance/controllers.csv](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/master/data/experiments/inputs/controllerPerformance/controllers.csv). Finally, there are experiment parameters in the `data/common` directory that apply to all parameters. These include definitions of parameters for the power systems equipment, customer models, and weather data.

The three key steps in parsing the data are generating the *experiment parameters*, the *confounding variables*, and the *independent variables* (also called the treatment variables). This is done in the methods `setupAdditionalParameters`, `generatingConfoundingVariables`, and `generateTreatmentVariables`, respectively. These methods parse the data found in the `data` folder and apply additional logic to generate synthetic data or expand the raw data set programmatically. Some of these expansion processes are random, but are seeded so they can be reproduced.

### Simulation Process
The simulation is executed by calling the method `simulateTreatment` in the `ContorllerPerformanceExperiment` class. This takes a *test-set* as an input, comprised of the specific confounding variables for that trial and independent/treatment variables (the general experiment parameters, which are unchanging, are stored in the property `ExperimentParams`).

This calls `simRHC` from [microgrid-dispatch-simulator](https://github.com/leejt489/microgrid-dispatch-simulator) to simulate the receding horizon control process and returns the output data. Please see this repo for details on using the simulation package and examples to run it in other contexts.

### Results Process
A `M x 2` cell array [`Metrics`](https://github.com/Energy-MAC/pscc2020-load-limiting/blob/0dee47389c9a7ab4710f0b0456593223dcb345e6/experiments/ControllerPerformanceExperiment.m#L10) defines each of `M` metrics as a pair of a string defining the name, and a function handle for computing the metric. Each of these functions require the output data and its associated test-set, and return a scalar metric. Thus, each of the metrics can be computed for each trial and for each independent variable. These are the values used to generate the plots shown in the paper. A metric can return `NaN` if it cannot be computed for that particular test-set.
