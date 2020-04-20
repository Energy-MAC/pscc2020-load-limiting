%% Generate tables found in the paper
% This script prints the tables in LaTex tabular format to the command
% line. Additional touches to the formatting necessary.
%% Activity table
t = readtable('data/common/user_types/A/activities.csv');
t = removevars(t,'standby_W');
t{:,'min_s'} = t{:,'min_s'}/60;
t{:,'max_s'} = t{:,'max_s'}/60;
disp(t);
for i = 1:size(t,1)
    a = t{i,1};
    fprintf('%s',a{1})
    for j = 2:size(t,2)
        fprintf('&%g',t{i,j});
    end
    fprintf('\\\\\\hline\r');
end

%% Computation time table
% Compute results
expObj = ComputationTimeExperiment();
trials = expObj.loadCompletedTrials();

ct = expObj.computeResultsDistributionMetricMultiple({'Time'}).Time;

medCT = median(ct,1);

% Print in table format
tv = trials(1).treatmentVariables;
t = nan(length(tv)/3,6);
for i = 1:length(tv)
    if (i <= length(tv)/3)
        t(i,1) = expObj.SampleN(tv(i).indN);
        t(i,2) = expObj.SampleS(tv(i).indS);
        t(i,3) = tv(i).T_hor;
        t(i,4) = medCT(i);
    elseif (i <= 2*length(tv)/3)
        t(i-12,5) = medCT(i);
    else
        t(i-24,6) = medCT(i);
    end
end
t = round(t*100)/100;
%t = round(t,0.01);
t(t > 1) = round(t(t > 1)*10)/10;
t(t > 10) = round(t(t > 10));
t = array2table(t,'VariableNames',{'N','S','T','Time_Det','Time_2_Stage','Time_DP'});
disp(t);
for i = 1:size(t,1)
    fprintf('%i',t{i,1});
    for j = 2:3
        fprintf('&%i',t{i,j});
    end
    for j = 4:size(t,2)
        fprintf('&%g',t{i,j});
    end
    fprintf('\\\\\\hline\r');
end