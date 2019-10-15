function uGState = createInitialState(users,userTypes,dayTypes,E_max,randomizeEstor)
%CREATEINITIALSTATE Summary of this function goes here
%   Detailed explanation goes here
if (nargin < 3)
    randomizeEstor = false;
end

N = length(users);

uGState.load = createInitialLoadState(users,userTypes,dayTypes);

if randomizeEstor
    uGState.Estor = rand(N,1).*E_max;
else
    uGState.Estor = 0.5*ones(N,1).*E_max;
end