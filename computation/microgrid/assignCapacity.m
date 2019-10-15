function userTable = assignCapacity(userTable,params,infParams,userTypes,dailyTable,hourlyTable,solarDataFile)
% TODO: Define a relationship between user type and expected mean load so
% we may compute total load. Pull in expected insolation in kWh/m^2/day as
% well. As a placeholder, assume mean value per user.
% SA: For now, generate one load realization based on create_uG and take
% that to be representative of the daily expected
daySeconds = 3600*24;
horizon_sec = daySeconds*params.T_experiment;

meanLoad = estimateMeanLoad(getUserStruct(userTable),params,dailyTable,hourlyTable,userTypes);

% TODO: something seems off with load vs solar daily kWh
% generate solar data from .mat file

[solarDaily, ~] = solarForecast(60, horizon_sec, daySeconds, params.startDay, solarDataFile);
meanInsolation = mean(mean(solarDaily)); %kW, mean across scenarios;

% SolarCap_total specifies the ratio of average solar generation to average
% load.
totalPVCapacity = params.solarCap_total*meanLoad/meanInsolation;
totalBatteryCapacity = params.batteryCap_total*totalPVCapacity;
% Randomly allocate PV capacity among N users.
% TODO: improve to round total capacity to multiple of microinverters, then
% allocate by generating N random integers that sum to
% totalPVCapacity/infParams.solarInverterCap for solar. See
% http://sunny.today/generate-random-integers-with-fixed-sum/ for
% reference (JL: haven't vetted this post).

% Randomly allocate batteries
batteryAllocationFactor = diff([0;sort(rand(params.N-1,1),1);1]); % Generates Nx1 matrix whose columns are randomly distributed (though maybe not uniformly) among columns with entries \in [0,1] and column sum = 1. Histograms look like exponential distribution.
batteries = round(batteryAllocationFactor*totalBatteryCapacity/infParams.batteryEnergyCap);
batteryUserInd = batteries > 0;
% Ensure at least 1 battery
if sum(batteryUserInd) == 0
    batteries(1) = 1;
    batteryUserInd = batteries > 0;
end

% Randomly allocate PV only to users with batteries
pvAllocationFactor = diff([0;sort(rand(sum(batteryUserInd)-1,1),1);1]);
PV = zeros(params.N,1);
PVperBattery = round(pvAllocationFactor*totalPVCapacity/infParams.solarInverterCap);
if sum(PVperBattery) == 0
    PVperBattery(1) = 1;
end
PV(batteryUserInd) = PVperBattery;

% Update the values for the PV and batteries
for n = 1:params.N
    userTable{n,'PV'} = PV(n);
    userTable{n,'batteries'} = batteries(n);
end
end


function meanLoad = estimateMeanLoad(users,params,dailyTable,hourlyTable,userTypes)
% computes mean (in time) load on the system from all users in kW
    
    meanLoad = 0;
    resolution = params.max_load_tstep;
    
    u = struct;
    u.ambientTemp = getAmbientTemp(hourlyTable,params.max_load_tstep);
    
    loadStates = createInitialLoadState(users,userTypes,dailyTable{:,'type'});

    for n = 1:params.N
        userType = getUserType(users(n),userTypes);
        % Create a random activity schedule
        
        y = simLoad(0,loadStates(n),u,resolution,userType);
        meanLoad = meanLoad + mean(y.totalLoadPower);
    end
    meanLoad = meanLoad/1000; %Convert to kW

end

