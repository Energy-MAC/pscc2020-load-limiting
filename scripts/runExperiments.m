%% Run experiment to compare controllers
expObj = ControllerPerformanceExperiment();
expObj.runTrialsSerFrom(1);

%% Run experiment for computation time
expObj = ComputationTimeExperiment();
trials = expObj.runExperiment('ser'); % Run timing experiments in series for more accurate results