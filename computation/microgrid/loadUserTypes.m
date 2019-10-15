function userType = loadUserTypes(globalDataFolder)
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
% Infer the type from the files
tmp = dir([globalDataFolder 'common/user_types']);
userTypeIds = {tmp(3:end).name}; % Returns 1 x numUserTypes cell array of type names
% Enforce unique

for k=1:length(userTypeIds)
    userType(k).type=userTypeIds{k};
    userType(k).act_table=readtable(fullfile(globalDataFolder,['common/user_types/' userTypeIds{k} '/activities.csv']));
    userType(k).thermal_table=readtable(fullfile(globalDataFolder,['common/user_types/' userTypeIds{k} '/thermal.csv']));
    userType(k).day_table_1=readtable(fullfile(globalDataFolder,['common/user_types/' userTypeIds{k} '/day_1.csv']));
    userType(k).day_table_2=readtable(fullfile(globalDataFolder,['common/user_types/' userTypeIds{k} '/day_2.csv']));
    userType(k).day_table_3=readtable(fullfile(globalDataFolder,['common/user_types/' userTypeIds{k} '/day_3.csv']));
    userType(k).th.on_W=userType(k).thermal_table{:,'on_W'};
    userType(k).th.standby_W=userType(k).thermal_table{:,'standby_W'};
    userType(k).th.cool_W_Th=userType(k).thermal_table{:,'cool_W_Th'};
    userType(k).th.cool_eff=userType(k).thermal_table{:,'cool_eff'};
    userType(k).th.kTh_W_K=userType(k).thermal_table{:,'kTh_W_K'};
    userType(k).th.Cp_J_K=userType(k).thermal_table{:,'Cp_J_K'};
    userType(k).th.temp_set_C=userType(k).thermal_table{:,'temp_set_C'};
    userType(k).th.hyst_C=userType(k).thermal_table{:,'hyst_C'};
    
    userType(k).n_act = size(userType(k).act_table,1);
    userType(k).n_therm = size(userType(k).thermal_table,1);
    
end
end

