function [x1, y] = simulateWindow(t,x0,u,params)

% Timing parameters
deltaT_cntr = params.deltaT_cntr;
deltaT_sim = params.deltaT_sim;
T = deltaT_cntr/deltaT_sim;

% Map variables to aggregated input for simOp
uPhys = struct;
%uPhys.maxLoad = (u.l*ones(1,T)*1000)';
uPhys.maxEnergy = u.l*deltaT_cntr/3600*1000; % Energy limit in Wh
uPhys.pSet = (u.Pinj*ones(1,T)*1000)';
uPhys.qSet = zeros(T,length(u.l));

uPhys.tAmbient = u.ambientTemp;
uPhys.irradiance = u.irradiance;

xPhys = x0;
xPhys.Estor = xPhys.Estor*1000;

% Simulate customer decision
N = params.N;

y.chi = zeros(N,length(u.ambientTemp)); % Interruptions
y.ci = zeros(N,length(u.ambientTemp)); % Interruption cost

milpOpts = optimoptions('intlinprog','Display','off');
for n = 1:N
    userType = getUserType(params.uG.user(n),params.uG.userType);
    xUser0 = x0.load(n);
    uUser = struct;
    uUser.energyLimit = uPhys.maxEnergy(n)/1000;
    [yUser,xPhys.load(n)] = simUser(t,xUser0,uUser,deltaT_sim,T,userType,milpOpts);
    uPhys.load(n).thermalEnabled = repmat(yUser.thermalEnabled',T,1);
    
    %Compute interruption cost
    y.chi(n,1) = sum(yUser.activityInterruptions)+sum(yUser.thermalInterruptions);
    y.ci(n,1) = yUser.activityInterruptions'*userType.act_table{:,'interrupt_USD'}...
        + yUser.thermalInterruptions'*userType.thermal_table{:,'interrupt_USD_C_h'}/3600*deltaT_sim;
end

[yPhys,xPhys] = simOp(t,xPhys,uPhys,params);

% Update state variable
x1 = x0;
x1.Estor = (xPhys.Estor(:))/1000; % Convert back to kWh
x1.load = xPhys.load;

y.Pu = yPhys.loadPower'/1000;
y.l = yPhys.maxLoad'/1000;
y.P = -yPhys.P'/1000;
y.Estor = yPhys.battWh'/1000;
y.Pw = yPhys.curtailedSolar'/1000;
y.xi = yPhys.blackout;
y.deltaOmega = yPhys.dF;
y.Pg = yPhys.Pg'/1000;

y.availability = yPhys.availability';

% Add total number of interruptions and cost for each user experienced
% during the window to those incurred at the beginning
for n = 1:size(y.Pu,1)
    y.chi(n,:) = y.chi(n,:) + (sum(yPhys.user(n).activityInterruptions,2)+sum(yPhys.user(n).thermalInterruptions,2))';
    userType = getUserType(params.uG.user(n),params.uG.userType); %TODO: pre-save user type to user to avoid always looking it up
    % Interruption costs. Mat mult below returns Tx1 vector of total costs
    % at each time.
    y.ci(n,:) = y.ci(n,:) + ([
            yPhys.user(n).activityInterruptions yPhys.user(n).thermalInterruptions
        ] * [
            userType.act_table{:,'interrupt_USD'};
            userType.thermal_table{:,'interrupt_USD_C_h'}/3600*deltaT_sim
        ])';
end