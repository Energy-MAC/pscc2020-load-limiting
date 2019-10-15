function [solar,solarScenarios] = solarForecast(nativeResolution, horizon_sec, desiredResolution_sec, dayOfYear, dataFilepath)
%SOLAR_FORECAST Generate a set of solar realizations from data
%   Example solar forecast generation from CAMS Radiation Service:
%   Data is manipulated in python with minimal dependencies and output in a
%   .mat file at 1 minute (native) resolution for the current data
%   native_freq: int, Set to 60 for 1 minute data, 1 for 1 second data, etc.
%   T_experiment: int (seconds), the duration of the experiment
%   deltaT_sim: int (seconds), the length of the timestep
%   day_of_year: int, the day of year with January 1st as 1.
%   data_filepath: str, the location of the .mat file to load
solarGHI = load(dataFilepath); % is in minutes (W/m^2) JTL: I think it is in cumulative Wh/m^2 per minute
solarGHI = solarGHI.solar_ghi*60/1000; % extract the matrix from the struct JTL: looks like  multiplying by 60 minutes / hour gives avg W/m^2 over each minute
startMinute = (dayOfYear-1)*60*24+1; % get the starting time in minutes. Minus 1 is for start of that day
solar = solarGHI(startMinute:startMinute+horizon_sec/nativeResolution-1,:);
% Takes the 1 minute data and transforms it to the simulation frequency
solar = resampleBasic(solar, nativeResolution, desiredResolution_sec);

%solar = solar ./ max(solar(:)); % convert the range to be in [0, 1]

% enumerate the possible choices for the solar
solarScenarios = size(solarGHI, 2); % get how many scenarios are available

end

