function u = getControlAction(algName,x,W,params)

Pg = W.Pg;
Pl = W.Pl;
ps = W.ps;

Estor = x.Estor;
gamma = x.gamma;

E_max = params.E_max;
Pl_max = params.Pl_max;
%Pt_max = params.Pt_max;
Pc_max = params.Pc_max;
P_max = params.Pl_max;

% Adjust by forecast horizon to be in units of hours(deltaT_hor)*kW
Estor = Estor/params.deltaT_hor*3600;
E_max = E_max/params.deltaT_hor*3600;

N = size(Estor,1);
l = nan(N,1);

netSOC = sum(Estor)/sum(E_max); % Average SOC of entire system

% Set injection with proportional feedback to keep batteries balanced for
% all controllers
Pinj = (Estor-netSOC*E_max)*params.K;

% For now, build a fully connected, unconstrained network to pass in to
% controllers that want a network
% Bbus = ones(N)-N*eye(N);
% Mbus = eye(N)+diag(ones(N-1,1),1);

switch algName
    case 'NoControl'
        l = Pl_max;
        %Pinj = (Estor-mean(Estor))/params.K;
    case 'Reactive' % Limits defined assuming Pl_max is 10 kW.
        if (netSOC >= 0.3)
            l = inf(N,1);
        elseif (netSOC < 0.3)
            l = 0.1*Pl_max;
        elseif (netSOC < 0.2)
            l = 0.05*Pl_max;
        elseif (netSOC < 0.1)
            l = 0.01*Pl_max;
        end
        %Pinj = (Estor-mean(Estor))/params.K;
    case 'Deterministic'
        % Adjust SOC to work within range above 10%
        minSOC = 0.1;
        Estor = max(Estor-minSOC*E_max,0); % Define initial SOC relative to 10%
        E_max = (1-minSOC)*E_max; % Consider capacity less than 10%
        
        l = scenarioFormulation2Stage1Look(...
            gamma,mean(Pg,3),mean(Pl,3),1,Estor,E_max,P_max,Pl_max,Pc_max...
        );
    case 'StochasticTrajectory'
        % Adjust SOC to work within range above 10%
        minSOC = 0.1;
        Estor = max(Estor-minSOC*E_max,0); % Define initial SOC relative to 10%
        E_max = (1-minSOC)*E_max; % Consider capacity less than 10%
        l = scenarioFormulation2Stage1Look(...
            gamma,Pg,Pl,ps,Estor,E_max,P_max,Pl_max,Pc_max...
        );
    case 'StochasticDP'
        % Adjust SOC to work within range above 10%
        minSOC = 0.1;
        Estor = max(Estor-minSOC*E_max,0); % Define initial SOC relative to 10%
        E_max = (1-minSOC)*E_max; % Consider capacity less than 10%
        
        l = scenarioFormulationBackRec(...
            gamma,Pg,Pl,ps,Estor,E_max,P_max,Pl_max,Pc_max...
        );
    otherwise
        error('Unknown algorithm name');
end

u = struct;
u.Pinj = Pinj;
u.l = l;