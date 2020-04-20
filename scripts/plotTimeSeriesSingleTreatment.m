function plotTimeSeriesSingleTreatment(expObj,trialInd,treatmentInd)
% Plot time series results for a particular treatment of a particular trial

% Load trial
trial = expObj.loadTrial(trialInd);

% Plot the time series using the function from MicrogridDispatchSimulator
MicrogridDispatchSimulator.Visualization.plotTimeSeries(trial.outputs(treatmentInd));