function userType = getUserType(user,userTypes)
% Gets the particular userType struct given a user and the collection of types
    userType = userTypes(strcmp(user.type,{userTypes.type}));
end