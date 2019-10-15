function loadPower = loadForecast(uG, S, desiredResolution, baseResolution)
%LOAD_FORECAST Forecast the load by calling a realization generator
%   This is a wrapper function for however the loads are generated.

%params = struct;
%params.tStart_sec = 


% Example random forecast generation:
N = length(uG.user);

u = struct;
u.ambientTemp = getAmbientTemp(uG.hourlyTable,baseResolution);

loadPower = zeros(N,length(u.ambientTemp)*baseResolution/desiredResolution,S);

% Create a forecast for each scenarios
for s = 1:S
    
    % Create initial load state, which includes random activity schedule
    loadStates = createInitialLoadState(uG.user,uG.userType,uG.dailyTable{:,'type'});

    for n = 1:N
        % Create a random activity schedule
        userType = getUserType(uG.user(n),uG.userType);

        % Simulate the users load for that activity schedule
        y = simLoad(0,loadStates(n),u,baseResolution,userType);
        
        % Resample to desired resolution and scale to kW
        loadPower(n,:,s) = resampleBasic(y.totalLoadPower, baseResolution, desiredResolution) / 1000;
    end
end


