function [pl_fore,pg_fore,pg_dist] = forecast(uG, S, params, infParams, solarFile)
%FORECAST Summary of this function goes here
%   Detailed explanation goes here
% create a collection of uG objects
native_solar_freq = 60; % seconds
horizon_sec = 3600*24*params.T_experiment;


pl_fore = loadForecast(uG, S, params.deltaT_hor, params.max_load_tstep);

[solar, ~] = solarForecast(native_solar_freq,horizon_sec,params.deltaT_sim,params.startDay,solarFile);

forecasts = randi(size(solar,2),[S,1]); % JTL: should we really be randomizing over user?
pg_fore_temp = solar(:, forecasts);

pg_fore = nan(params.N, horizon_sec/params.deltaT_hor,S);
pg_dist = nan(horizon_sec/params.deltaT_sim,1);
for n=1:params.N
    % Pg_fore needs to be scaled by capacity
    % selection is with replacement
    %forecasts = randi(size(solar,2),[S,1]); % JTL: should we really be randomizing over user?
    %pg_fore_temp = solar(:, forecasts);
    pg_fore(n,:,:) = resampleBasic(pg_fore_temp, params.deltaT_sim, params.deltaT_hor) * uG.user(n).nPV*infParams.solarInverterCap;


end

% Pg_dist should be unscaled but in kW, (not normalized), and not per
% user
dist = randi(size(solar,2),1);
pg_dist(:) = solar(:, dist);