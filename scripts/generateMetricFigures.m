caseName = [];
expObj = ControllerPerformanceExperiment(caseName);
%% Plot convergence of quadratic objective metric over trials
params = struct;
params.treatmentLabels = {'No Control','Prop. Feedback','Deterministic','2-Stage Traj.','DP'};

figure;
params.metricLabel = 'Quad. Obj.';
expObj.plotMetricConvergence('Objective',params);

figure;
params.metricLabel = 'Cust. Util.';
expObj.plotMetricConvergence('UserUtility',params);

figure;
params.metricLabel = 'ASAI';
expObj.plotMetricConvergence('ASAI',params);

%% Compare ex ante objective to ex post
params.metricNames = {'ObjectivePred','ObjectivePost'};
params.metricLabels = {'Obj Pred','Obj Post'};

expObj.plotResultsDistributionMetrics(params);

%% Show the distribution of ex post metrics of interest
params.metricNames = {'Objective','UserUtility','CompletedValue','InterruptionCost','ASAI'};
params.metricLabels = {'Obj','User Util.','Value','Int. Cost','ASAI'};

% Make bar charts comparing them
expObj.plotResultsDistributionMetrics(params);

% Make histograms of each
for m = 1:length(params.metricNames)
    expObj.plotResultsDistributionTreatment(params.metricNames{m},params.treatmentLabels);
end

%% Show the distribution of ex post metrics of interest normalized relative to no control
params.normalization = 'percentChangeByTrial';
params.baseIndex = 1; % Index of no control treatment
expObj.plotResultsDistributionMetrics(params);

% Show specific comparison of the customer completed value and interruption
% cost
params.metricNames = {'CompletedValue','InterruptionCost'};
params.metricLabels = {'Value','Cost'};
expObj.plotResultsDistributionMetrics(params);
