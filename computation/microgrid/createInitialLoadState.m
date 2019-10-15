function loadState = createInitialLoadState(users,userTypes,dayTypes)
%CREATEINITIALLOADSTATE Summary of this function goes here
%   Detailed explanation goes here

loadState = struct;
for n = 1:length(users)
    userType = getUserType(users(n),userTypes);
    loadState(n).thermal.temp=userType.thermal_table{:,'temp_set_C'}; % Initial temperatures equal the setpoints
    loadState(n).thermal.thermOn=false(size(loadState(n).thermal.temp)); % all thermostats begin in the off state
    loadState(n).activitySchedule = createActivitySchedule(userType,dayTypes);
end
loadState = loadState';

end


function actSchedule = createActivitySchedule(userType,dayTypes)
% Day types is an vector specifying the type of day of each

% Calculate schedule of activities                                     
nActTypes=size(userType.act_table,1);
actSchedule=[]; 
for d=1:length(dayTypes)
    day_type=dayTypes(d);
    this_day_table=userType.(['day_table_' num2str(day_type)]);
    %% Calculate activities
    % updates the activities transitions table
    % columns  1:activity number ; 2: start time ; 3:end time
    for act=1:nActTypes
        if this_day_table{25,act+1}>0
            nAct=randi(this_day_table{25,act+1},1);
            day_schedule=schedule_activity(this_day_table{1:24,act+1},... % creates a schedule references to the current day
                nAct,userType.act_table{act,'min_s'},...
                userType.act_table{act,'max_s'});
            if size(day_schedule,1)>0
                actSchedule=[actSchedule;...
                    [act*ones(size(day_schedule,1),1),day_schedule+(d-1)*3600*24]]; % add  the day referenced to the entire simulation window
            end
        end
    end


end
end
