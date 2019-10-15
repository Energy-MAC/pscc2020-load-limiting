%function [allInterrupts,P,loadPower,battWh,uG,dF,blackout]=simOp(tStart,uG,ctl,tStep)
function [y,x]=simOp(tStart,x,u,params)
%SIMOP Represents the operation of a microgrid with only real-time
%controls enabled
% 2019, Claudio Vergara, Zola Electric.

% tStart: absolute time in seconds
% x: system state
% u: inputs
% params: system parameters

% simOp evolves the state. The resolution of the trajectory is implicitly
% specified by the input trajectories, u, at a time resolution specified by
% params.deltaT_sim

%% Setup
tStep = params.deltaT_sim;
uG = params.uG;

% Get temperature and irradiance as inputs
tAmbient = u.tAmbient;
PV_max = u.irradiance;

nSamples=size(PV_max,1);
nUsers=length(uG.user);

pSet = u.pSet;

if isfield(u,'maxLoad')
    maxLoad = u.maxLoad;
else
    maxLoad = inf(nSamples,nUsers);
end

if isfield(u,'maxEnergy')
    maxEnergy = u.maxEnergy;
else
    maxEnergy = inf(nUsers,1);
end


y = struct;

% hardcoded frequency control values
beta_per_W=4; % specific stiffness per kW of inverter capacityin W/Hz
dF=zeros(nSamples,1); % frequency deviation due to power balancing

% Create parameter arrays  
battWh=zeros(nSamples+1,nUsers); % energy stored in the battery of each user
battSOC=zeros(nSamples,nUsers); 

loadPower=zeros(nSamples,nUsers);
availability = false(nSamples,nUsers);
blackout=zeros(nSamples,1); % Indicates a total blackout for a given second

beta=zeros(nUsers,1);

uGBalance=zeros(nSamples,1);
P=zeros(nSamples,nUsers); % power consumption from the microgrid by user
Pg=zeros(nSamples,nUsers);

INF_P=zeros(nUsers,1);


% Simulate unconstrained consumption to check if consumption must be adjusted
x_load0 = cell(nUsers,1);
x_load1 = cell(nUsers,1);
thermEnabled = cell(nUsers,1);

for n=1:nUsers
    
    %TODO: vectorize these
    %% Infinity data                                                        
    PVWp(n)=uG.user(n).nPV*300; % installed PV capacity in W
    battNomWh(n)=uG.user(n).nBatt*2000; % rated battery capacity in Wh
    battNomW(n)=uG.user(n).nBatt*1200; % inverter power in W
    battWh(1,n)=x.Estor(n);  
    beta(n)=beta_per_W*(battNomW(n)+PVWp(n)); % Infinity tie-line flow stiffness in kW/Hz
    
    userTypes(n) = getUserType(uG.user(n),uG.userType);
    x_load0{n} = x.load(n);
    
    try
        thermEnabled{n} = u.load(n).thermalEnabled;
    catch
        thermEnabled{n} = true(nSamples,userTypes(n).n_therm);
    end
    
    % Preallocate results
    y.user(n).activityInterruptions = false(nSamples,userTypes(n).n_act);
    y.user(n).thermalInterruptions = false(nSamples,userTypes(n).n_therm);
end

%% Simulation     
u_load = struct;
for t=1:nSamples
    
    absTime = tStart-1+(t-1)*tStep; % absolute time in seconds
    
    % Infinity power limits on each time step
    % Must be redefined at each time step to preserve dimension (needed
    % because the size changes, and if it goes down to a scalar and then is
    % built back out, it will be 1xN instead of Nx1.
    INF_max_P=zeros(nUsers,1); 
    INF_min_P=zeros(nUsers,1);
    INF_max_dF=zeros(nUsers,1);
    INF_min_dF=zeros(nUsers,1);
    maxBattOut=zeros(nUsers,1);
    maxBattIn=zeros(nUsers,1);
   
    %% Step 1: Correct controls, curtail load
    for n=1:nUsers 
        %% 1A Calculate limits and correct control setpoint                 
        % calculate the maximum tie-line limits for this user's Infinity
        % system and clamp the control setpoint if needed
                                                                
        battSOC(t,n)=battWh(t,n)/battNomWh(n);
        
        % Battery injection and withdrawal limits
       
        if battSOC(t,n)<0.1 % when the battery gets to 10% SOC, begin reducing the maximum output 
            maxBattOut(n)=min(battWh(t,n)/tStep*3600,battNomW(n)*battSOC(t,n)/0.1);
        else
            maxBattOut(n)=min(battWh(t,n)/tStep*3600,battNomW(n));
        end
        
        if battSOC(t,n)>0.9 % when the battery gets to 90% SOC, begin reducing the maximum input 
            maxBattIn(n)=min((battNomWh(n)-battWh(t,n))/tStep*3600,battNomW(n)*(1-battSOC(t,n))/0.1);
        else
            maxBattIn(n)=min((battNomWh(n)-battWh(t,n))/tStep*3600,battNomW(n));
        end
        PVMaxGen(n)=PVWp(n)*PV_max(t);
        
        % maximum injection and withdrawal
        INF_max_P(n)=PVMaxGen(n)+maxBattOut(n); 
        INF_min_P(n)=-maxBattIn(n);
       
        % correct setpoint
        pSet(t,n)=max(INF_min_P(n),min(INF_max_P(n),pSet(t,n)));
        % frequency response saturation point
        INF_min_dF(n)=-(INF_max_P(n)-pSet(t,n))/beta(n); % when the frequency decreases, the injection from Infinity increases
        INF_max_dF(n)=(pSet(t,n)-INF_min_P(n))/beta(n); % when the frequency increases, the injection from Infinity decreases      
        
        %% Simulate the load
        %u_load.maxLoad = maxLoad(t,n);
        u_load = struct;
        u_load.thermalEnabled = thermEnabled{n};
        u_load.ambientTemp = tAmbient(t);
        u_load.powerAvailable = ~blackout(t);
        if (sum(loadPower(1:t-1,n))*tStep/3600 > maxEnergy(n)) % energy limit exceed
            u_load.powerAvailable = false; % disconnect all loads
        end
        [y_load,x_load1{n}] = simLoad(absTime,x_load0{n},u_load,tStep,userTypes(n));
        
        y.user(n).activityInterruptions(t,:) = y_load.activityInterruptions;
        y.user(n).thermalInterruptions(t,:) = y_load.thermalInterruptions;
        availability(t,n) = u_load.powerAvailable;
        
        loadPower(t,n) = y_load.totalLoadPower;
    end
        
    %% 1C Net power                                                     
    % difference between the load and the corrected tie-line flow from
    % Infinity
    P(t,:)=loadPower(t,:)-pSet(t,:);
    %% Step 2: Microgrid frequency/power balancing 
    
    % remove users without Infinity system
    
    can_reduce=~isnan(INF_max_dF)& INF_max_dF~=0;
    can_increase=~isnan(INF_min_dF)& INF_min_dF~=0;
    
    INF_max_dF=INF_max_dF(can_reduce); 
    INF_min_dF=INF_min_dF(can_increase); % correcting users without Infinity system
    
    beta_down=beta(can_increase); % responses to underfrequency
    beta_up=beta(can_reduce); % responses to overfrequency
    
    uGBalance(t)=sum(P(t,:)); % net withdrawals from all the users
       
    
    [dF(t),blackout(t)]=calc_frequency(INF_min_dF,INF_max_dF,uGBalance(t),beta_up,beta_down); % frequency deviation and blackout condition
    
    if (blackout(t))
        %maxLoad(t+1:end,:)=0.5*maxLoad(t+1:end,:); %TODO: make this 0.5 factor a parameter
        %disp(['blackout in step' num2str(t) ', reducing load limits by 50%']);
        %TODO: JTL: we discussed having the blackout persist for some time.
        %Also need to either enforce that maxLoad cannot be infinity or
        %include a max with a max load value.
    end
    
    %% Step 3: Update the operation of infinity systems and load    
    for n=1:nUsers
        % still charge from PV and exchange energy
        if blackout(t)

            if (availability(t,n))
                % Then load sim was performed with availability, so re-do
                % it without availability
                % Re-simulate load under blackout conditions
                u_load.powerAvailable = false;
                [y_load,x_load1{n}] = simLoad(absTime,x_load0{n},u_load,tStep,userTypes(n));
                
                if (y_load.totalLoadPower)
                    error('Something is wrong. Load model should return 0 under blackout conditions');
                end
                y.user(n).activityInterruptions(t,:) = y_load.activityInterruptions;
                y.user(n).thermalInterruptions(t,:) = y_load.thermalInterruptions;
                availability(t,n) = false;
            end
            
            loadPower(t,n)=0; % clear the load

            PVMaxGen=PVWp(n)*PV_max(t);
            pBatt=max(-maxBattIn(n),-PVMaxGen); % Infinity systems can still charge from PV
            P(t,n)=0; % all users don't exchange power with the grid
        else
            dP1(n)=-dF(t)*beta(n);
            INF_P(n)=max(INF_min_P(n),min(INF_max_P(n),pSet(t,n)+dP1(n)));
            pBatt=min(maxBattOut(n),max(-maxBattIn(n),INF_P(n)-PVMaxGen(n))); % results in the least PV curtailment
            P(t,n)=loadPower(t,n)-INF_P(n);
        end
        battWh(t+1,n)=battWh(t,n)-tStep*pBatt/3600;
        x_load0{n} = x_load1{n};
        Pg(t,:) = PVMaxGen; %TODO: verify this is correct
    end   
    uGBalance(t)=sum(P(t,:));  % record the new balance after corrections
     
end

%uG.balance=uGBalance;

% Assign outputs
y.P = P;
y.loadPower = loadPower;
y.battWh = battWh(1:end-1,:); % The last value is captured in the final state
y.dF = dF;
y.blackout = blackout;
y.maxLoad = maxLoad;
y.curtailedSolar = nan(size(maxLoad)); %TODO: compute this
y.Pg = Pg;
y.availability = availability;

% Update state variable
x.Estor = battWh(end,:)';
for n = 1:nUsers
    x.load(n) = x_load1{n};
end

end

function [dF,blackout] = calc_frequency(INF_min_dF,INF_max_dF,uGBalance,beta_up,beta_down)

beta_down=beta_down+1e-9*rand(size(beta_down)); % avoides identical values
beta_up=beta_up+1e-9*rand(size(beta_up)); % avoides identical values

INF_min_dF=INF_min_dF+1e-9*rand(size(INF_min_dF)); % avoides identical values
INF_max_dF=INF_max_dF+1e-9*rand(size(INF_max_dF)); % avoides identical values

blackout=false;

if uGBalance == 0
    dF = 0;
elseif uGBalance<0 % Injections exceed withdrawals -> need to increase the frequency
    % Interpret imbalance as a positive value for below
    uGBalance = -uGBalance;
    %% upward frequency response curve, used to reduce injections from Infinity
    
    nUsers=length(beta_up);
    
    [max_dF,I1]=sort(INF_max_dF);
    
    for u=1:nUsers
        sys_beta_up(u)=sum(beta_up(I1>=u));
        if u==1
            sys_dP_up(u)=sys_beta_up(u)*max_dF(u);
        else
            sys_dP_up(u)=sys_dP_up(u-1)+(max_dF(u)-max_dF(u-1))*sys_beta_up(u);
        end
    end
    
    %% Calculate the new frequency and service state
    
    if uGBalance>sys_dP_up(end) % the microgrid can't absorb the imbalance
        blackout=true;
        
        dF=0;
    else % interpolate the upward correction table
        
        dF=interp1([0,sys_dP_up],[0;max_dF],uGBalance);
    end
    
else %  % Withdrawals exceed injections -> need to decrease the frequency
    
    %% downward frequency response curve, used to increase injections from Infinity
    nUsers=length(beta_down);
    
    [min_dF,I2]=sort(-INF_min_dF);
    
    for u=1:nUsers
        sys_beta_down(u)=sum(beta_down(I2>=u));
        if u==1
            sys_dP_down(u)=sys_beta_down(u)*min_dF(u);
        else
            sys_dP_down(u)=sys_dP_down(u-1)+(min_dF(u)-min_dF(u-1))*sys_beta_down(u);
        end
    end
    %% calculate the new frequency and service state
    if uGBalance>sys_dP_down(end) % the microgrid can't absorb the imbalance
        blackout=true;
        dF=0;
    else % interpolate the downward correction table
        dF=-interp1([0,sys_dP_down],[0;min_dF],uGBalance);
    end
end

end

