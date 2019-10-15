%% Compute computation time table
expObj = ComputationTimeExperiment();
trials = expObj.loadCompletedTrials();

ct = expObj.computeResultsDistribution(@expObj.metricTime,false);

meanCt = mean(ct,1);
tv = trials(1).treatmentVariables;
t = nan(length(tv)/3,6);
for i = 1:length(tv)
    if (i <= length(tv)/3)
        t(i,1) = expObj.SampleN(tv(i).indN);
        t(i,2) = expObj.SampleS(tv(i).indS);
        t(i,3) = tv(i).T_hor;
        t(i,4) = meanCt(i);
    elseif (i <= 2*length(tv)/3)
        t(i-12,5) = meanCt(i);
    else
        t(i-24,6) = meanCt(i);
    end
end
t = round(t,1);
t(t > 10) = round(t(t > 10));
array2table(t,'VariableNames',{'N','S','T','Time_Det','Time_2_Stage','Time_DP'})
%matrix2latex(t,'paper/time_table.tex','columnLabels',{'N','S','T','Time: Det.','Time: 2 Stage','Time: DP'})