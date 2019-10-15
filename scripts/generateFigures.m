%% Forecast Interpretation Figure
S = 2;
T = 3;
Ts = 2;
Te = Ts+T-1;
deltaT2 = 100;
expObj = ControllerPerformanceExperiment();
p = expObj.ExperimentParams;
p.deltaT_hor = 3600*24;
p.uG = expObj.loadTrial(1).confoundingVariables.uG;
p.startDay = expObj.loadTrial(1).confoundingVariables.startDay;

[Pl,Pg] = forecast(p.uG, S, p, p.infParams, p.solarDataFile);
Pl = Pl(:,Ts:Te,:); Pg = Pg(:,Ts:Te,:);
netPc0 = reshape(sum(Pg-Pl),[T,S]);
netPc = resampleBasic(netPc0,deltaT2,1,0); % Zero-order hold interpolation

E_max = sum(p.infParams.batteryEnergyCap*[p.uG.user.nBatt])/24;
Estor0 = 0.3*E_max;

Estor_traj = nan(T*deltaT2+1,S);
Estor_traj(1,:) = Estor0;
for t = 1:(T*deltaT2)
    Estor_traj(t+1,:) = min(E_max,max(Estor_traj(t,:)+netPc(t,:)/deltaT2,0));
end

figure;
set(gcf,'Position',get(gcf,'Position').*[1 1 0.9 0.8]);
subplot(3,1,1);
plot(0:1/deltaT2:(T-1/deltaT2),netPc);
ylabel('kW');
title('Charge power forecast for different scenarios: P^g_t-P^l_t');
legend({'s = 1','s = 2'},'location','SouthWest')
ax = gca;
ax.XGrid = 'on';
ylim(1.1*get(ax,'YLim'));

subplot(3,1,2);
hold on
plot([0 T],E_max*[1 1],'--k');
plot(0:1/deltaT2:T,Estor_traj);
ylim([0 1.1*E_max]);
ylabel('kW \times \Delta T');
legend('E_{max}','location','Best');
title('E^{stor}_{t} w/ trajectory scenario interpretation');
ax = gca;
ax.XGrid = 'on';

subplot(3,1,3);
hold on
Estor0_tmp = Estor0;
plot([0 T],E_max*[1 1],'--k')
for t = 1:T
    Estor1_tmp = nan(S^t,1);
    for i = 1:size(Estor0_tmp,1)
        Estor_indp = nan(deltaT2,S);
        Estor_indp(1,:) = repmat(Estor0_tmp(i)',[1 S]); % something not right here
        for t2 = 1:deltaT2
            Estor_indp(t2+1,:) = min(E_max,max(Estor_indp(t2,:)+netPc0(t,:)/deltaT2,0));
        end
        plot((t-1):1/deltaT2:t,Estor_indp)
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
    if (i < 3)
        xticklabels({});
    else
        xticklabels({'t','t+1','t+2','t+3'});
    end
end
%saveas(gcf,'paper/figures/scenarios','epsc');
%saveas(gcf,'paper/figures/scenarios','png');
%% Controller Performance Figure
expObj = ControllerPerformanceExperiment();
trials = expObj.loadCompletedTrials();

expParams = expObj.ExperimentParams;

normToFirstCol = @(x) (x(:,2:end)./repmat(x(:,1)+1e-10,1,size(x,2)-1)-1)*100;

controllerLabels = {'Prop. Feedback','Deterministic','2-Stage Traj.','DP Markov'};

bObjective = expObj.computeResultsDistribution(@expObj.metricObjectiveFore,true);
bObjective2 = normToFirstCol(bObjective);
interruptionCost = expObj.computeResultsDistribution(@expObj.metricInterruptionCost,false);
interruptionCost2 = -normToFirstCol(interruptionCost);
ASAI = expObj.computeResultsDistribution(@expObj.metricASAI,false);
ASAI_2 = normToFirstCol(ASAI);


figure;
set(gcf,'Position',get(gcf,'Position').*[1 1 1.1 0.7]);
y = [mean(interruptionCost2);mean(ASAI_2);mean(bObjective2)]';
bar(y);
set(gca,'XTickLabel',controllerLabels);
hold on

% Add error bars; thanks to https://www.mathworks.com/matlabcentral/answers/438514-adding-error-bars-to-a-grouped-bar-plot
err = [std(interruptionCost2);std(ASAI_2);std(bObjective2)]';
nGroups = size(y,1); nBars = size(y,2);
groupwidth = min(0.8, nBars/(nBars + 1.5));
for i = 1:nBars
    x = (1:nGroups) - groupwidth/2 + (2*i-1) * groupwidth / (2*nBars);
    errorbar(x, y(:,i), err(:,i),'.k');
end

legend('Neg. Int. Cost','ASAI','Quad. Obj.','Std. Dev.','Location','NorthWest');
ylabel('% change relative to no control');
title('Controller Performance');
ax = gca;
ax.YGrid = 'on';

%saveas(gcf,'paper/figures/performance','epsc');
%saveas(gcf,'paper/figures/performance','png');

%%
% Compute average load
for i = 1:length(trials)
    meanPl_fore(i) = mean(mean(mean(trials(i).confoundingVariables.forecasts.Pl)));
    meanPuNoControl(i) = mean(mean(trials(i).outputs(1).timeseries.Pu));
end
meanLoad = mean(meanPl_fore); % Will be in kW