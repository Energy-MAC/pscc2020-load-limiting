function [irradianceForecast,irradianceRealization,maxScenarios] = solarForecast(S, horizon_sec, desiredResolution_sec, dayOfYear, dataFilepath)
%SOLAR_FORECAST Generate a set of solar realizations from data
%   Example solar forecast generation from CAMS Radiation Service:
%   Data is manipulated in python with minimal dependencies and output in a
%   .mat file at 1 minute (native) resolution for the current data
%   native_freq: int, Set to 60 for 1 minute data, 1 for 1 second data, etc.
%   T_experiment: int (seconds), the duration of the experiment
%   deltaT_sim: int (seconds), the length of the timestep
%   day_of_year: int, the day of year with January 1st as 1.
%   data_filepath: str, the location of the .mat file to load

import MicrogridDispatchSimulator.DataParsing.loadSolarData

irradiance = loadSolarData(dataFilepath, dayOfYear, horizon_sec, desiredResolution_sec);

maxS = size(irradiance,2)-1;
if (S <= maxS)
    % Get a random permutation of possible indices. The first S are the
    % forecast and the S+1 is the realization
    ind = randperm(size(irradiance,2),S+1);
    irradianceForecast = irradiance(:,ind(1:S));
    irradianceRealization = irradiance(:,S+1);
else
    % Get an index for the realization
    realizationInd = randi(size(irradiance,2));
    t = 1:size(irradiance,2); % Possible samples
    t(realizationInd) = []; % Remove the realization from the sample
    % Select each remaining sample floor(S/maxS) times and then randomly
    % choose the remainder to get to S.
    ind = [repmat(1:maxS,1,floor(S/maxS)) randperm(maxS,mod(S,maxS))];
    irradianceForecast = irradiance(:,t(ind));
    irradianceRealization = irradiance(:,realizationInd);
end
maxScenarios = maxS;

end

