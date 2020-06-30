import MicrogridDispatchSimulator.DataParsing.createUsers
import MicrogridDispatchSimulator.Simulation.simLoad
import MicrogridDispatchSimulator.Models.MeterRelay

trials = expObj.CompletedTrials;
T = 7*3600*24;
deltaT = expObj.ExperimentParams.deltaT_sim;
for i = 1:length(trials)
    userParams = trials(i).confoundingVariables.userParams;
    users = createUsers(userParams);
    N = userParams.N;
    % Create a dummy bus to connect loads to (they must have a source)
    m = MeterRelay();
    results = struct; % Struct array, will be length N
    Pl = 0;
    for n = 1:N
        user = users(n);
        user.Meter = m; % Connect to the bus
        user.createActivities(T,deltaT); % Need to explicitly create a set of activities over the time window at a certain resolution
        user.initializeState(); % Need to initialize the state
        Pl = Pl + mean(simLoad(0,struct,T,deltaT,user));
    end
    meanLoadPerUser(i) = Pl/N;
    meanBatteriesPerUser(i) = mean(userParams.NBatteries);
    meanPVPerUser(i) = mean(userParams.NPV);
    fprintf('Load: %g W, Batteries: %g, PV: %g\r',meanLoadPerUser(i),meanBatteriesPerUser(i),meanPVPerUser(i));
end