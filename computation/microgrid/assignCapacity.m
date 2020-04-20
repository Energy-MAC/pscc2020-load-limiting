function [nPV,nBatteries] = assignCapacity(params)
% TODO: Define a relationship between user type and expected mean load so
% we may compute total load. Pull in expected insolation in kWh/m^2/day as
% well. As a placeholder, assume mean value per user.
% SA: For now, generate one load realization based on create_uG and take
% that to be representative of the daily expected

import MicrogridDispatchSimulator.DataParsing.createUsers;
import MicrogridDispatchSimulator.DataParsing.loadSolarData

daySeconds = 3600*24;
horizon_sec = daySeconds*params.T_experiment;
N = params.N;
derParams = params.derParams;
solarDataFile = params.solarDataFile;
solarCap_total = params.solarCap_total;
batteryCap_total = params.batteryCap_total;
startDay = params.startDay;
max_load_tstep = params.max_load_tstep;

userParams = struct;
userParams.N = N;
userParams.userTypes = params.userTypes;

meanLoad = estimateMeanLoad(createUsers(userParams),horizon_sec,max_load_tstep);

% TODO: something seems off with load vs solar daily kWh
% generate solar data from .mat file

solarDaily = loadSolarData(solarDataFile, startDay, horizon_sec, daySeconds);
meanInsolation = mean(mean(solarDaily)); %kW, mean across scenarios;

% SolarCap_total specifies the ratio of average solar generation to average
% load.
totalPVCapacity = solarCap_total*meanLoad/meanInsolation;
totalBatteryCapacity = batteryCap_total*totalPVCapacity;
% Randomly allocate PV capacity among N users.
% TODO: improve to round total capacity to multiple of microinverters, then
% allocate by generating N random integers that sum to
% totalPVCapacity/infParams.solarInverterCap for solar. See
% http://sunny.today/generate-random-integers-with-fixed-sum/ for
% reference (JL: haven't vetted this post).

% Randomly allocate batteries
batteryAllocationFactor = diff([0;sort(rand(N-1,1),1);1]); % Generates Nx1 matrix whose columns are randomly distributed (though maybe not uniformly) among columns with entries \in [0,1] and column sum = 1. Histograms look like exponential distribution.
nBatteries = round(batteryAllocationFactor*totalBatteryCapacity/derParams.batteryEnergyCap);
batteryUserInd = nBatteries > 0;
% Ensure at least 1 battery
if sum(batteryUserInd) == 0
    nBatteries(1) = 1;
    batteryUserInd = nBatteries > 0;
end

% Randomly allocate PV only to users with batteries
pvAllocationFactor = diff([0;sort(rand(sum(batteryUserInd)-1,1),1);1]);
nPV = zeros(N,1);
PVperBattery = round(pvAllocationFactor*totalPVCapacity/derParams.solarInverterCap);
if sum(PVperBattery) == 0
    PVperBattery(1) = 1;
end
nPV(batteryUserInd) = PVperBattery;
end


function meanLoad = estimateMeanLoad(users,T,deltaT)
% computes mean (in time) load on the system from all users in kW

    import MicrogridDispatchSimulator.Simulation.simLoad;
    import MicrogridDispatchSimulator.Models.MeterRelay;
    
    meanLoad = 0;
    
    u = struct;
    %u.ambientTemp = getAmbientTemp(hourlyTable,deltaT);
    
    b = MeterRelay();

    for n = 1:length(users)
        users(n).createActivities(T,deltaT);
        % Create a random activity schedule
        
        users(n).Meter = b; % Assign a dummy bus to the user so the load may run
        Pl = simLoad(0,u,T,deltaT,users(n));
        meanLoad = meanLoad + mean(Pl);
    end
    meanLoad = meanLoad/1000; %Convert to kW

end

