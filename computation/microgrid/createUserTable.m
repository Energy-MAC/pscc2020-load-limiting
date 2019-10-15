function userTable = createUserTable(N,userTypes)
% Process for now will be to define different user types sequentially (see
% loop below).

% Make user table
userTable = table('Size',[N, 6],...
    'VariableTypes',{'double','string','double','double','double','string'},...
    'VariableNames',{'user','type','PV','batteries','node','contract'});
for n = 1:N
    userTable{n,'user'} = n;
    userTable{n,'type'} = userTypes(mod(n-1,length(userTypes))+1).type; % Evenly assign user type
    userTable{n,'PV'} = 0;
    userTable{n,'batteries'} = 0;
    userTable{n,'node'} = 1; % TODO: determine network generation protocol
    userTable{n,'contract'} = '0'; % TODO: replace if it is being used in a relevant way
end

end

