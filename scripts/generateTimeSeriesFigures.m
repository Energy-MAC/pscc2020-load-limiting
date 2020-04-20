%% Visualize results
%% Load experiment
% Load the ControllerPerformanceExperiment, assuming it has already been
% executed using 'runExperiment'. This loads the default case, but a
% specific case can be specified, e.g.
% expObj = ControllerPerformanceExperiment('sample');
expObj = ControllerPerformanceExperiment();

%% Plot time series output for example trial
% Select example trial
trialInd = 1;

% Make figures for time series using the 2-stage stochastic programming
% approach (treatmend index 4) for trial 1.
close all;
plotTimeSeriesSingleTreatment(expObj,trialInd,4);

% SoC figure
f = figure(6);
setPageSize(f);
saveas(f,'figures/soc','epsc');
saveas(f,'figures/soc','png');
print -dpdf -painters figures/soc;

% Load limit figure
f = figure(9);
setPageSize(f);
saveas(f,'figures/load_limits','epsc');
saveas(f,'figures/load_limits','png');
print -dpdf -painters figures/load_limits;

% Make figures comparing the 2-stage stochastic programming approach to the
% deterministic forecast approach feedback.
plotTimeSeriesCompareTreatment(expObj,trialInd,4,3,'Stoch. Program','Deterministic');

% Compare SoC
f = figure(10);
setPageSize(f);
saveas(f,'figures/soc_compare','epsc');
saveas(f,'figures/soc_compare','png');
print -dpdf -painters figures/soc_compare;

%%

function setPageSize(f)
u1 = get(f,'Units');
set(f,'Units','inches');
screenposition = get(f,'Position');
set(f,...
    'PaperPosition',[0 0 screenposition(3:4)],...
    'PaperSize',screenposition(3:4));
set(f,'Units',u1);
end
