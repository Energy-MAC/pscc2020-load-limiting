function [pl_fore,pg_fore,pg_dist,ps] = forecast(userParams, S, params, solarFile)
%FORECAST Summary of this function goes here
%   Detailed explanation goes here
% create a collection of uG objects

import MicrogridDispatchSimulator.DataParsing.createUsers
import MicrogridDispatchSimulator.Utilities.resampleBasic

horizon_sec = 3600*24*params.T_experiment;
deltaT_hor = params.deltaT_hor;
deltaT_sim = params.deltaT_sim;
max_load_tstep = params.max_load_tstep;
startDay = params.startDay;

% Get the load forecast
pl_fore = loadForecast(userParams, S, horizon_sec, deltaT_hor, max_load_tstep);



% Get the solar irradiance forecast 
[irradianceForecast,irradianceRealization, ~] = solarForecast(S,horizon_sec,deltaT_sim,startDay,solarFile);
pg_dist = nan(horizon_sec/deltaT_sim,1);
pg_dist(:) = irradianceRealization;

% Rescale to forecast time scale
irradianceForecast = resampleBasic(irradianceForecast, deltaT_sim, deltaT_hor);

% Pg_fore needs to be scaled by capacity for each user. Units are in average kW
% production over the time period
users = createUsers(userParams);
N = length(users);
% Preallocate solar forecast
pg_fore = nan(N, horizon_sec/deltaT_hor,S);
for n=1:N
    pg_fore(n,:,:) =  irradianceForecast * users(n).NPV*users(n).PVUnitCapacity/1000;
end

% Assign probability weights to the forecasts
ps = ones(S,1)/S;
