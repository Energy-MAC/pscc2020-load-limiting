%% Run experiment to compare controllers
expObj = ControllerPerformanceExperiment('sample');
expObj.runExperiment('ser');

%% Run experiment for computation time
expObj = ComputationTimeExperiment('sample');
trials = expObj.runExperiment('ser'); % Run timing experiments in series for more accurate results