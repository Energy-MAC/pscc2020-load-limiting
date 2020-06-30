%% Generate figures 
disp('Generating figures. This may take some time...');
%% Load experiment object
expObj = ControllerPerformanceExperiment();

%% Define colors for different metrics
objColor = [0    0.4510    0.7412];
utilColor = [0.9294    0.6902    0.1294];
asaiColor = [0.4902    0.1804    0.5608];
objAnteColor = [0.4706    0.6706    0.1882];
meanLoadColor = [0.8510    0.3294    0.1020];

%% Make performance figure
params = struct;
params.barOpts.percentile = 0.05;
params.barOpts.FaceColor = [objColor;utilColor;asaiColor];
params.treatmentLabels = {'No Control','Prop. Feedback','Deterministic','2-Stage','ADP'};
params.metricNames = {'Objective','UserUtility','ASAI'};
params.metricLabels = {'Obj.','Cust. Util.','ASAI'};

f = figure;
expObj.plotResultsDistributionMetrics(params);
title('');
ylabel('');
xlabel('');
legend(params.metricLabels);

% Adjust figure sizing
set(f,'Position',get(f,'Position').*[1 1 1.1 0.8]);
shrinkWhitespace(gca);
setPageSize(f);

% Save in eps and pdf formats
print -dpdf -painters figures/performance
saveas(f,'figures/performance','epsc');
saveas(f,'figures/performance','png');

%% Make figure comparing predictive controllers
params = struct;
params.treatmentInd = [3:5];
params.barOpts.percentile = 0.05;
params.normalization = 'percentChangeByTrial';
params.baseIndex = 3;
params.treatmentLabels = {'Deterministic','2-Stage','ADP'};
params.metricNames = {'AverageLoadLimit','AverageLoadLimitFrequency','UserUtility','CompletedValue','InterruptionCost'};
params.metricLabels = {'Limit','Limit Time','Util.','Cmpl. Val.','Int. Cost'};
f = figure;
set(f,'Position',get(f,'Position').*[1 1 1.1 0.8]);
expObj.plotResultsDistributionMetrics(params);
title('');
xlabel('');
ylabel('% change');
legend('Location','NorthEast');

shrinkWhitespace(gca);
setPageSize(f);

% Save in eps and pdf formats
saveas(f,'figures/predictive_compare','epsc');
saveas(f,'figures/predictive_compare','png');
print -dpdf -painters figures/predictive_compare

%% 
params = struct;
%params.normalization = 'percentChangeByTrial';
%params.baseIndex = 1;
params.barOpts.percentile = 0.05;
params.barOpts.FaceColor = [meanLoadColor;objColor;objAnteColor];
params.treatmentLabels = {'No Control','Prop. Feedback','Deterministic','2-Stage','ADP'};
params.metricNames = {'MeanLoad','ObjectivePost','ObjectivePred'};
params.metricLabels = {'Mean Load','Obj. Ex Post','Obj. Ex Ante'};

f = figure;
set(f,'Position',get(f,'Position').*[1 1 1.1 0.8]);
expObj.plotResultsDistributionMetrics(params);
set(legend(gca,'show'),...
    'Position',[0.265080394025341 0.661332196534395 0.186688315226992 0.196712024164772]);
xlabel('');
ylabel('');
title('');
ylim([0.1 0.35]);
legend(params.metricLabels);

shrinkWhitespace(gca);
setPageSize(f);

% Save in eps and pdf formats
saveas(f,'figures/obj_performance','epsc');
saveas(f,'figures/obj_performance','png');
print -dpdf -painters figures/obj_performance
%% Forecast Interpretation Figure
S = 2;
T = 3;
Ts = 2;
Te = Ts+T-1;
deltaT2 = 100;

netPc = [1.3 0.8 0.1;2.2 -1.6 -1]';
E_max = 4;
Estor0 = 0.3*E_max;

Estor_traj = nan(T*deltaT2+1,S);
Estor_traj(1,:) = Estor0;
for t = 1:(T*deltaT2)
    netPct = netPc(floor((t-1)/deltaT2)+1,:);
    Estor_traj(t+1,:) = min(E_max,max(Estor_traj(t,:)+netPct/deltaT2,0));
end

figure;
set(gcf,'Position',get(gcf,'Position').*[1 1 0.9 0.6]);
subplot(3,1,1);
plot([0 1 1 2 2 3],[netPc(1,:);netPc(1:2,:);netPc(2:3,:);netPc(3,:)],'LineWidth',1);
ylabel('kW');
title('Charge power forecast for different scenarios: P^g_t-P^l_t');
legend({'s = 1','s = 2'},'location','SouthWest')
ax = gca;
ax.XGrid = 'on';
ylim([-2.5 2.5]);

subplot(3,1,2);
hold on
plot([0 T],E_max*[1 1],'--k','LineWidth',1);
plot(0:1/deltaT2:T,Estor_traj,'LineWidth',1);
ylim([0 1.1*E_max]);
ylabel('kW \times \Delta T');
legend('E_{max}','location','Best');
title('E^{stor}_{t} w/ trajectory scenario interpretation');
ax = gca;
ax.XGrid = 'on';

subplot(3,1,3);
hold on
Estor0_tmp = Estor0;
plot([0 T],E_max*[1 1],'--k','LineWidth',1)
for t = 1:T
    Estor1_tmp = nan(S^t,1);
    for i = 1:size(Estor0_tmp,1)
        Estor_indp = nan(deltaT2,S);
        Estor_indp(1,:) = repmat(Estor0_tmp(i)',[1 S]); % something not right here
        for t2 = 1:deltaT2
            Estor_indp(t2+1,:) = min(E_max,max(Estor_indp(t2,:)+netPc(t,:)/deltaT2,0));
            %Estor_indp(t2+1,:) = min(E_max,max(Estor_indp(t2,:)+netPc0(t,:)/deltaT2,0));
        end
        plot((t-1):1/deltaT2:t,Estor_indp,'LineWidth',1)
        Estor1_tmp((i-1)*S+1:i*S) = Estor_indp(deltaT2+1,:);
        ax = gca;
        ax.ColorOrderIndex = 1;
    end
    Estor0_tmp = Estor1_tmp;
end
ylim([0 1.1*E_max]);
ylabel('kW \times \Delta T');
title('E^{stor}_{t} w/ Markov scenario interpretation');
ax = gca;
ax.XGrid = 'on';

for i = 1:3
    subplot(3,1,i);
    xticks(0:T);
	xticklabels({});
end

f = gcf;
for i = 1:2:length(f.Children)
    shrinkWhitespace(f.Children(i));
end
xticklabels(f.Children(1),{'t','t+1','t+2','t+3'});
setPageSize(f);

saveas(gcf,'figures/scenarios','epsc');
saveas(gcf,'figures/scenarios','png');
print -dpdf -painters figures/scenarios;



%%
disp('...done!');
%%
function shrinkWhitespace(ax)
outerpos = ax.OuterPosition;
ti = ax.TightInset; 
left = outerpos(1) + ti(1) + 0.01;
bottom = outerpos(2) + ti(2) + 0.01;
ax_width = outerpos(3) - ti(1) - ti(3) - 0.03;
ax_height = outerpos(4) - ti(2) - ti(4) - 0.02;
ax.Position = [left bottom ax_width ax_height];
end

function setPageSize(f)
u1 = get(f,'Units');
set(f,'Units','inches');
screenposition = get(f,'Position');
set(f,...
    'PaperPosition',[0 0 screenposition(3:4)],...
    'PaperSize',screenposition(3:4));
set(f,'Units',u1);
end