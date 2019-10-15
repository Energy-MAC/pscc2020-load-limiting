%function load_ts=simLoad(tStart_sec,uG,horizon_sec,desiredResolution_sec,tStep_sec)
function [y,x1] = simLoad(t,x0,u,tStep,userType)
y = struct;

x = x0;

tAmbient = u.ambientTemp;

if isfield(u,'powerAvailable')
    powerUnavailable = ~u.powerAvailable;
else
    powerUnavailable = false;
end

horizon_secs = length(tAmbient)*tStep;

actTable = userType.act_table;
nActTypes=size(actTable,1);
nThermTypes=size(userType.thermal_table,1);

if isfield(u,'thermalEnabled')
    thermEnabled = u.thermalEnabled;
else
    thermEnabled = true(size(tAmbient,1),nThermTypes) & powerUnavailable; % Defaults to true; thermal loads always enabled unless blackout
end

absTime=t:tStep:t+horizon_secs-1; % in seconds

% Set up matrix for computing activity power
% actPower = A1*x + b1, where x is activity state
A1 = (actTable{:,'on_W'}-actTable{:,'standby_W'})';
b1 = sum(actTable{:,'standby_W'});

y.activityInterruptions = false(length(tAmbient),nActTypes);
y.thermalInterruptions = false(length(tAmbient),nThermTypes);

if (powerUnavailable)
    y.totalLoadPower = zeros(length(tAmbient),1);
    thermEnabled(:) = false; % Disable thermal loads
    for tau=1:length(tAmbient)
        % Get activity state for this time only
        actState = getActivityState(x.activitySchedule, nActTypes, absTime(tau), tStep);
        
        % Activities and thermal loads to be interrupted are those that
        % are on.
        actInterrupt = find(actState); % TODO: check what it means for a standby activity to be interrupted.
        thermInterrupt = x.thermal.thermOn; %TODO: check what it means to interrupt a thermal load on standby
        
        % Record that interruption happened at this time for activity/load
        y.activityInterruptions(tau,actInterrupt) = true;
            
        y.thermalInterruptions(tau,thermInterrupt) = true;
        % Disable thermal loads to be interrupted
        thermEnabled(tau,thermInterrupt) = false;
        
        % Remove interrupted activities from the master list
        for actInd=actInterrupt
            %TODO double check this timing
            ind1=x.activitySchedule(:,2)<absTime(tau) &...
                x.activitySchedule(:,3)>absTime(tau); % true when the current time is within the activity

            ind2=x.activitySchedule(:,1)==actInd; % true when the activity corresponds to the one that will be interrupted

            x.activitySchedule(ind1 & ind2,:)=[]; % eliminates the activity from the schedule
        end
        
        % Update thermal loads
        x.thermal = thermalUpdate(x.thermal, thermEnabled(tau,:)', tAmbient(tau), userType, tStep);

    end
else
    % Can simulate all activities at once because we are not considering
    % constraints.
    actState = getActivityState(x.activitySchedule, nActTypes, absTime, tStep);

    % First set activity power, then add thermal as we loop over time
    y.totalLoadPower = actState*(A1') + b1;

    % Advance thermal loads and add to total power
    for tau = 1:horizon_secs/tStep
        % Build another matrix for thermal power consumption based on state
        A2 = (userType.th.on_W-userType.th.standby_W).*x.thermal.thermOn + userType.th.standby_W;
        thermPower = thermEnabled(tau,:)*A2;
        y.totalLoadPower(tau) = y.totalLoadPower(tau) + thermPower;
        x.thermal = thermalUpdate(x.thermal, thermEnabled(tau,:)', tAmbient(tau), userType, tStep);
    end
end

x1 = x;
end

function actState = getActivityState(actSchedule,nActTypes,absTime,tStep)
%UNTITLED10 Summary of this function goes here
%   Detailed explanation goes here

%tStart = absTime(1);
%tEnd = absTime(end)+tStep-1;
actState=false(length(absTime),nActTypes);

% JTL: this commented out code just filters the activity schedule before
% searching again, which is not necessary.
% % Activity states    
% actStart=actSchedule(:,2); % start time of all the activities in the year
% actEnd=actSchedule(:,3); % end time of all the activities in the year
% x1=actStart>=tStart & actStart<tEnd; % activity starts within the window
% x2=actEnd>=tStart & actEnd<tEnd; % activity ends within the window
% x3=actStart<tStart & actEnd>tEnd; % activity starts before and ends after the window
% actSchedule=actSchedule(x1 | x2 | x3,:);


for i=1:size(actSchedule,1)
    x1=absTime+tStep > actSchedule(i,2); % Activity starts before this time window ends
    x2=absTime <= actSchedule(i,3); % Activity did not end before this time window starts
    actState(x1 & x2,actSchedule(i,1))=true;
end
end

function state = thermalUpdate(state, thermEnabled, tAmbient, userType, tStep)
% THERMALUPDATE updates the thermal state for the simulation. 
% avgPower is average (in time) of the sum of power from all loads

nThermTypes = size(userType.thermal_table,1);

% Update state of each
for TL=1:nThermTypes
            
    %% Temperature update
    T0=state.temp(TL); % initial temperature
    COP=max(userType.th.cool_W_Th(TL)/userType.th.on_W(TL),...
        min(1,userType.th.cool_eff(TL)*T0/(tAmbient-T0))); % coefficient of performance

    cooling_out=max(0,state.thermOn(TL)*userType.th.on_W(TL)*COP); % heat evaquated by the cooling system in W
    passive_out=(T0-tAmbient)*userType.th.kTh_W_K(TL); % passive energy loss in W
    energy_out=tStep*(cooling_out+passive_out); % total energy tranferred to the ambient in J
    state.temp(TL)=T0-energy_out/userType.th.Cp_J_K(TL); % thermal state update

    %% Thermostat update and output calculaation
    if state.thermOn(TL)
        if T0<userType.th.temp_set_C(TL)-userType.th.hyst_C(TL)/2
            % Turn off if temp is below threshold
            state.thermOn(TL)=0;
        else
            % Set to on/off based on whether load is enabled
            state.thermOn(TL)=1*thermEnabled(TL);
        end
    else
        if T0>userType.th.temp_set_C(TL)+userType.th.hyst_C(TL)/2
            % Turn on if temp above threshold and enabled
            state.thermOn(TL)=1*thermEnabled(TL);
        end
        
    end
end
    
end