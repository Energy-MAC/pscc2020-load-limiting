%%
close all;clear;clc;

expObj = ControllerPerformanceExperiment('sample');
params = expObj.ExperimentParams;
trials = expObj.loadCompletedTrials();

time = (0:params.deltaT_sim:params.T_experiment*3600*24-1)/3600;

%% Compute some metrics across controllers
% Each return matrix is # of trials by # of controllers
bObjective = expObj.computeResultsDistribution(@expObj.metricObjective,true);
interruptionCost = expObj.computeResultsDistribution(@expObj.metricInterruptionCost,false);
numActInterruptions = expObj.computeResultsDistribution(@expObj.metricInterruptions,false);
ASAI = expObj.computeResultsDistribution(@expObj.metricASAI,false);
ASAI100 = expObj.computeResultsDistribution(@expObj.metricASAI100,false);
ASAI500 = expObj.computeResultsDistribution(@expObj.metricASAI500,false);
ASAI1000 = expObj.computeResultsDistribution(@expObj.metricASAI1000,false);
ASAI2000 = expObj.computeResultsDistribution(@expObj.metricASAI2000,false);

%% Look at a particular trial and control algorithm
k = 1; % Index of trial;
i = 1; % Index of control algorithm used
policies = {'No control','Reactive','Deterministic',...
    'Stochastic 1-Step Lookahead','Stochastic Discretized DP'};

trial = trials(k);
outputs = trial.outputs;

Estor = outputs(i).timeseries.Estor;
Pu = outputs(i).timeseries.Pu;
Pw = outputs(i).timeseries.Pw;
P = outputs(i).timeseries.P;
Pg = outputs(i).timeseries.Pg;
l = outputs(i).timeseries.l;
l2 = outputs(i).timeseries.l2;
Pinj = outputs(i).timeseries.Pinj;
xi = outputs(i).timeseries.xi;
deltaOmega = outputs(i).timeseries.deltaOmega;
chi = outputs(i).timeseries.chi;
ci = outputs(i).timeseries.ci;
SOC = Estor./repmat(trial.confoundingVariables.E_max,1,size(Estor,2));

%% Simulate what load would have been
%Uncomment to perform another simulation of unconstrained load only

% N = params.N;
% u = struct;
% u.ambientTemp = trial.controllingVariables.disturbances.ambientTemp;
% Pl = nan(size(Pu));
% uG = params.uG;
% for n = 1:N
%     y_load = simLoad(1,trial.controllingVariables.uGState.load(n),u,params.deltaT_sim,getUserType(uG.user(n),uG.userType));
%     Pl(n,:) = y_load.totalLoadPower;
% end
% Pl = Pl/1000; % convert to kW
% figure;
% plot(time,sum(Pl));

%% System net load - solar
figure;
plot(time,sum(Pu-Pg)');
title('Net load minus solar kW');
%% Total load
figure;
plot(time,sum(Pu));
%% Battery charge
figure;
plot(time,sum(Estor),time,xi);
title('Total battery kWh')
legend('Estor','blackout');

figure;
plot(time,SOC)
title('Relative SOC');
%% Injection into grid
figure;
plot(time,Pinj)
title('Net injection setpoint Pinj')

figure;
plot(time,P)
title('Net injection actual P')
%% Total interruption cost
figure;
plot(time,sum(ci));
title('Total interruption cost');
%% Total interruptions
figure;
plot(time,sum(chi));
title('Total interruptions');
%% Individual interruption cost
figure;
plot(time,ci);
title('Individual interruption cost (USD)');
%% Individual interruptions
figure;
plot(time,chi);
title('Individual number of interruptions)');
%% Individual load
figure;
plot(time,Pu');
title('Pu');
%% Load limits
figure;
plot(time,l');
title('Individual load limits (control)');

%% Curtailed load
% figure;
% plot(time,Pl-Pu);
% title('Load absent constraints minus with')

%% Comparison of two control policies
k = 1; % Index of trial
i = 1;
j = 4;
diff_str = [policies{i}, ' - ', policies{j}];

trial = trials(k);
outputs = trial.outputs;

Estor = outputs(i).timeseries.Estor;
Pu = outputs(i).timeseries.Pu;
Pw = outputs(i).timeseries.Pw;
P = outputs(i).timeseries.P;
Pg = outputs(i).timeseries.Pg;
l = outputs(i).timeseries.l;
l2 = outputs(i).timeseries.l2;
Pinj = outputs(i).timeseries.Pinj;
xi = outputs(i).timeseries.xi;
deltaOmega = outputs(i).timeseries.deltaOmega;
chi = outputs(i).timeseries.chi;
ci = outputs(i).timeseries.ci;

Estor_j = outputs(j).timeseries.Estor;
Pu_j = outputs(j).timeseries.Pu;
Pw_j = outputs(j).timeseries.Pw;
P_j = outputs(j).timeseries.P;
Pg_j = outputs(j).timeseries.Pg;
l_j = outputs(j).timeseries.l;
l2_j = outputs(j).timeseries.l2;
Pinj_j = outputs(j).timeseries.Pinj;
xj = outputs(j).timeseries.xi;
deltaOmega_j = outputs(j).timeseries.deltaOmega;
chi_j = outputs(j).timeseries.chi;
cj = outputs(j).timeseries.ci;

%% Battery charge
figure;
subplot(311);
plot(time,sum(Estor),time,xi);
title(['Total battery kWh: ', policies{i}] )
legend('Estor','blackout');
subplot(312);
plot(time,sum(Estor_j),time,xj);
title(['Total battery kWh: ', policies{j}] )
legend('Estor','blackout');
subplot(313);
plot(time,sum(Estor)-sum(Estor_j),time,xi-xj);
title(['Total battery kWh: ', diff_str] )
legend('Estor','blackout');
%% Total interruption cost
figure;
subplot(311);
plot(time,sum(ci));
title(['Total interruption cost: ', policies{i}]);
subplot(312);
plot(time,sum(cj));
title(['Total interruption cost: ', policies{j}]);
subplot(313);
plot(time,sum(ci)-sum(cj));
title(['Total interruption cost: ', diff_str]);
%% Total interruptions
figure;
subplot(311);
plot(time,sum(chi));
title(['Total interruptions:', policies{i}]);
subplot(312);
plot(time,sum(chi_j));
title(['Total interruptions:', policies{j}]);
subplot(313);
plot(time,sum(chi)-sum(chi_j));
title(['Total interruptions:', diff_str]);
%% Individual interruption cost
figure;
subplot(311);
plot(time,ci);
title(['Individual interruption cost (USD): ', policies{i}]);
subplot(312);
plot(time,cj);
title(['Individual interruption cost (USD): ', policies{j}]);
subplot(313);
plot(time,ci-cj);
title(['Individual interruption cost (USD): ', diff_str]);
%% Individual interruptions
figure;
subplot(311);
plot(time,chi);
title(['Individual number of interruptions: ', policies{i}]);
subplot(312);
plot(time,chi_j);
title(['Individual number of interruptions: ', policies{j}]);
subplot(313);
plot(time,chi-chi_j);
title(['Individual number of interruptions: ', diff_str]);
%% Individual load
figure;
subplot(311);
plot(Pu');
title(['Pu: ', policies{i}]);
subplot(312);
plot(Pu_j');
title(['Pu: ', policies{j}]);
subplot(313);
plot(Pu'-Pu_j');
title(['Pu: ', diff_str]);