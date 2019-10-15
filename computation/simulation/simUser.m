%function load_ts=simLoad(tStart_sec,uG,horizon_sec,desiredResolution_sec,tStep_sec)
function [y,x1] = simUser(t,x0,u,tStep,T,userType,milpOpts)
% t: current time in seconds
% x0: initial state struct
% u: input struct. Can have .energyLimit in units of kWh
% tStep: length of time step in seconds
% T: number of time steps

% y: output struct.
%   y.thermalEnabled: nThermTypes x T binary matrix for whether each thermal
%   load is enabled or not at that time
%   y.activityOn: nActTypes x T binary matrix for whether each activity is
%   enabled or not.
%   y.activityInterruptions: nThermTypes x T binary matrix for whether
%   activity was interrupted at that time
%   y.thermalInterruptions: nThermTypes x T binary matrix whether thermal
%   load was interrupted at that time
y = struct;

x = x0;

% tAmbient = u.ambientTemp;
% 
% try
%     blackout = u.blackout;
% catch
%     blackout = false;
% end
try
    energyLimit = u.energyLimit;
    considerLimit = true;
catch
    considerLimit = false;
end

horizon_secs = T*tStep;

actTable = userType.act_table;
nActTypes=size(actTable,1);
thermTable = userType.thermal_table;
nThermTypes=size(userType.thermal_table,1);

thermEnabled = true(nThermTypes,1); % Defaults to true; thermal loads always enabled
thermInterruptions = zeros(nThermTypes,1);
actInterruptions = zeros(nActTypes,1);

absTime=t:tStep:t+horizon_secs-1; % vector for time in seconds

if (considerLimit)
    % Get planned activities within this time window
    windowActInd = (x0.activitySchedule(:,2) < t+horizon_secs) & (x0.activitySchedule(:,3) >= t);
    plannedActs = x0.activitySchedule(windowActInd,:);
    nPlannedActs = size(plannedActs,1);
    actEnergy = nan(nPlannedActs,1); % Energy if the activity is carried out

    for i = 1:nPlannedActs
        actTimeInWindow = min(plannedActs(i,3),t+horizon_secs-1)-max(plannedActs(i,2),t); % Max and min term intentionally ignores energy outside window
        actEnergy(i) = actTable{plannedActs(i,1),'on_W'}*actTimeInWindow/3600/1000; % convert J to kWh
    end

    nOnTherm = sum(x0.thermal.thermOn);
    thermOnInd = find(x0.thermal.thermOn);

    thermEnergy = nan(nOnTherm,1);

    for i = 1:nOnTherm
        thermEnergy(i) = thermTable{thermOnInd(i),'on_W'}*horizon_secs/3600/1000; % convert J to kWh
    end
    
    % Constraints for MILP
    A = -[actEnergy;thermEnergy]';
    b = energyLimit+sum(A);
    
    % First check if constraint satisfied for no interruption
    if (b < 0)
        % User must make some interruptions

        % Compute vectors for interruption cost
        actInterruptCost = nan(nPlannedActs,1); % Cost to interrupt any of the planned activities
        thermInterruptCost = nan(nOnTherm,1);
        for i = 1:nPlannedActs
            actInterruptCost(i) = actTable{plannedActs(i,1),'interrupt_USD'};
        end
        for i = 1:nOnTherm
            thermInterruptCost(i) = thermTable{thermOnInd(i),'interrupt_USD_C_h'}*horizon_secs/3600; % Scale cost per hour by number of hours in window
        end
        
        % Setup MILP
        f = [actInterruptCost;thermInterruptCost];
        intcon=1:size(A,2);
        lb=zeros(size(A));
        ub=ones(size(A));
        
        % Compute which loads to interrupt. This doesn't consider
        % standby power or thermal load state changes, so still produce a decision
        % that violates the limit, but represents a customer's guess
        [x_opt,~,exitFlag]=intlinprog(f,intcon,A,b,[],[],lb,ub,ones(size(A))',milpOpts); % x returns activites and thermal loads to interrupt
        if (exitFlag ~= 1)
            error('intlinprog exited with bad exit flag: %i',exitFlag);
        end
        
        % Coerce x_opt to binary
        x_opt = abs(x_opt);
        x_opt(x_opt < 1e-6) = 0; % Check for values very close to zero
        x_opt = logical(x_opt);
        
        % Get indices of interrupted loads
        windowActIndNum = find(windowActInd);
        actInterruptInd = windowActIndNum(x_opt(1:nPlannedActs)); % Index into master activity list
        thermInterruptInd = thermOnInd(x_opt(nPlannedActs+1:end)); % Index into list of all thermal loads
        
        % Tally interruptions
        for i = actInterruptInd
            actInterruptions(x.activitySchedule(i,1)) = actInterruptions(x.activitySchedule(i,1))+1;
        end
        for i = thermInterruptInd
            thermInterruptions(i) = thermInterruptions(i)+1;
        end
        
        % Remove interrupted activities from the master list
        x.activitySchedule(actInterruptInd,:) = [];
        
        % Disable thermal loads
        thermEnabled(thermInterruptInd) = false;
        
        
    end
    
end
    
y.activityOn = getActivityState(x.activitySchedule,nActTypes,absTime,tStep);
y.thermalEnabled = thermEnabled;
y.activityInterruptions = actInterruptions;
y.thermalInterruptions = thermInterruptions;

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

