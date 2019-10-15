function [uG,uGState] = create_uG(globalDataFolder,experimentName,nDays,firstDay)
%CREATE_UG returns a structure of microgrid users
%   Each user has a unique sequence of activities and thermal loads 
%   determined probabilistically from their user type description

% 2019, Claudio Vergara, Zola Electric.  


%% Consolidate output                                                       
uG = struct;
uG.branch=[]; % placeholder
uG.node=[]; % placeholder

[uG.dailyTable,uG.hourlyData] = loadTimeTables(globalDataFolder,nDays,firstDay);
uG.userType = loadUserTypes(gGlobalDataFolder);
userTable = loadUsers(globalDataFolder,experimentName);
uG.user = getUserStruct(userTable);

uGState = createInitialState(uG.user,uG.userType,uG.dailyTable{:,'type'},2*[uG.user.nBatt]');

end

