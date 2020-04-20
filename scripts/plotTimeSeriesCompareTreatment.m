function plotTimeSeriesCompareTreatment(expObj,trialInd,treatmentInd1,treatmentInd2,treatmentName1,treatmentName2)

if (nargin < 5)
    treatmentName1 = sprintf('Treatment %i',treatmentInd1);
end

if (nargin < 6)
    treatmentName2 = sprintf('Treatment %i',treatmentInd2);
end

trial = expObj.loadTrial(trialInd);
outputs = trial.outputs;
MicrogridDispatchSimulator.Visualization.plotTimeSeriesCompare(outputs(treatmentInd1),outputs(treatmentInd2),treatmentName1,treatmentName2);