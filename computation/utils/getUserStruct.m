function user = getUserStruct(userTable)


%% Create users
nUsers=size(userTable,1);
for u=1:nUsers
    %% Basic data                                                           
    user(u).type=userTable{u,'type'};
    user(u).node=userTable{u,'node'};
    user(u).nBatt=userTable{u,'batteries'};
    user(u).contract=userTable{u,'contract'};    
    user(u).nPV=userTable{u,'PV'};
end

end

