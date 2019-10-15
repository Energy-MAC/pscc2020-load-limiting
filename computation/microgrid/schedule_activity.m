function [actSchedule] = schedule_activity(pStart,nAct,minDuration,maxDuration)
%SCHEDULE_ACTIVITY generates random occurrences of daily activities

% Each row of actSchedule corresponds to 1 occurrence of the activity, with
%  columns [start_second, end_second]. Second 1 begins at 00:00:00 of the
%  current day, and transitions happen a the beginning of each second.
% schedule_activity will avoid occurrences overlaps, and doesn't generate 
% multi-day activy schedules. The number of rows in actSchedule will be at
% most nAct, subject to scheduling feasibility.

% 2019, Claudio Vergara, Zola Electric.

numbers=[]; % sampling array

actSchedule=nan(nAct,2);

for k=1:nAct
    
   if sum(pStart)>0
       
    %% Generate the sampling vector    
    for i=1:24
        if pStart(i)>0
            numbers=[numbers;repmat(i,pStart(i),1)];
        end
    end
    
    %% Create random occurrence    
    startHour=numbers(randi(length(numbers)));
    startSecond=3600*(startHour-1)+randi(3600);
    duration=min(24*3600-startSecond,floor(minDuration+(maxDuration-minDuration)*rand()));
    endSecond=startSecond+duration;    
    actSchedule(k,:)=[startSecond,endSecond];
    
    %% Update pStart
    pStart(startHour:startHour+floor(duration/3600))=0; % a new occurrence can't star during the currently active hours    
   end    
end

actSchedule(isnan(actSchedule(:,1)),:)=[]; % eliminate the rows that were not populated

end