function [dailyTable,hourlyTable] = loadTimeTables(globalDataFolder,nDays,firstDay)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here

% For now, keep hourly and daily outside of case
hourlyTable=readtable(fullfile(globalDataFolder,'common/hourly.csv')); 
all_days_table=readtable(fullfile(globalDataFolder,'common/daily.csv'));

dailyTable=all_days_table(firstDay:firstDay+nDays-1,:);
hourlyTable=hourlyTable((firstDay-1)*24+1:(firstDay-1+nDays)*24,:);
end

