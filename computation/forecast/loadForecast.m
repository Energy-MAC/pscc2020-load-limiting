function loadPower = loadForecast(userParams, S, horizon, desiredResolution, baseResolution)
%LOAD_FORECAST Forecast the load by calling a realization generator
%   This is a wrapper function for however the loads are generated.

import MicrogridDispatchSimulator.Simulation.simLoad
import MicrogridDispatchSimulator.Models.MeterRelay
import MicrogridDispatchSimulator.DataParsing.createUsers
import MicrogridDispatchSimulator.Utilities.resampleBasic

% Example random forecast generation:
if (isfield(userParams,'N'))
    N = userParams.N;
elseif (isfield(userParams,'userTable'))
    N = size(userParams.userTable,1);
else
    error('Number of users not specified');
end

u = struct;
%u.ambientTemp = getAmbientTemp(hourlyTable,baseResolution);

loadPower = zeros(N,horizon/desiredResolution,S);

b = MeterRelay(); % Dummy bus to attach loads to

% Create a forecast for each scenarios
for s = 1:S
    
    users = createUsers(userParams);

    for n = 1:N
        % Create a random activity schedule
        users(n).createActivities(horizon,baseResolution);
        % Assign meter to user
        users(n).Meter = b;
        
        % Simulate the load
        Pl = simLoad(0,u,horizon,baseResolution,users(n));
        
        % Resample to desired resolution and scale to kW
        loadPower(n,:,s) = resampleBasic(Pl, baseResolution, desiredResolution) / 1000;
    end
end


