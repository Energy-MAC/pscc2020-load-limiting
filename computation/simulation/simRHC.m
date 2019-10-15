function [yt,xf] = simRHC(params,x0,controllerName,disturbances,forecasts)

if (nargin < 5 || isempty(forecasts))
    useForecast = false;
else
    useForecast = true;
end

N = params.N;
S = params.S;
T_experiment = params.T_experiment;
deltaT_sim = params.deltaT_sim;
deltaT_cntr = params.deltaT_cntr;
T_hor = params.T_hor;
deltaT_hor = params.deltaT_hor;

T =T_experiment*24*3600/deltaT_sim;

yt = struct; % Outputs trajectory

% Outputs defined for each user
yt.Estor = nan(N,T); % Battery state
yt.Pu = nan(N,T); % Power actually used
yt.Pw = nan(N,T); % Power wasted (i.e. solar that could not be used)
yt.P = nan(N,T); % Actual net injection
yt.l = nan(N,T); % Load limit (control sent)
yt.Pinj = nan(N,T); % Injection setpoint
yt.Pg = nan(N,T); % PV generated
%yt.Pl = nan(N,T); % Unconstrained load profile
yt.xi = nan(N,T); % Blackout
y.chi = nan(N,T); % Number of interruptions
y.ci = nan(N,T); % Cost of interruption
yt.l2 = nan(N,T); % Load limit (potentially modified by system after blackout)

% Outputs defined for system
yt.xi = nan(T,1);
yt.deltaOmega = nan(T,1);

W = struct;
W.ps = ones(S,1)/S;

x = x0; % State at an instant
w = struct; % Disturbances at an instant

for t = 1:deltaT_cntr/deltaT_sim:T
    absTime = (t-1)*deltaT_sim+1;
    
    % Print progress
%     if (t>1)
%         fprintf(repmat('\b',1,length(s))); % Delete old line
%     end
%     s = sprintf('Time: %i of %i; Percent: %2.1f\r',t,T_experiment*24*3600/deltaT_sim,t/T_experiment/24/3600*deltaT_sim*100);
%     fprintf(s);

    if (useForecast)
        % Construct forecast object
        % Resample time series to appropriate resolution
        W.Pg = forecasts.Pg(:,(t-1)/(deltaT_hor/deltaT_sim)+1:min((t-1)/(deltaT_hor/deltaT_sim)+T_hor,end),:);
        W.Pl = forecasts.Pl(:,(t-1)/(deltaT_hor/deltaT_sim)+1:min((t-1)/(deltaT_hor/deltaT_sim)+T_hor,end),:);

        %TODO: remove these workarounds handling errors once
        %fixed.
        if (any(W.Pl < 0))
            warning('Load forecast is returning negative numbers');
            W.Pl(W.Pl < 0) = 0;
        end
        if (any(isnan(W.Pg)))
            warning('Solar forecast is returning NaNs');
            W.Pg(isnan(W.Pg)) = 0;
        end
    end

    % Get control actions for each algorithm
    %TODO: Make sure to modify x(i) to keep storage >= 0...
    u = getControlAction(controllerName,x,W,params);

    % Grab solar data over the window
    u.irradiance = disturbances.irradiance(t:t+deltaT_cntr/deltaT_sim-1);
    u.ambientTemp = disturbances.ambientTemp(t:t+deltaT_cntr/deltaT_sim-1);
    % Get the load activity schedule for this window
%     w.actSchedule = cell(N,1);
%     for n = 1:N
%         actSchedule = disturbances.actSchedules{n};
%         % Get activities that are not completed by the beginning of the period and starting before the end of the period
%         actInd = actSchedule(:,3) > t & actSchedule(:,2) < t+deltaT_cntr/deltaT_sim;
%         tmp = actSchedule(actInd,:);
%         tmp(:,[2 3]) = tmp(:,[2, 3]) - (t-1);
%         w.actSchedule{n} = tmp;
%     end

    
    [xf, y] = simWindow(absTime,x,u,params); % x as input is initial state, gets overwritten with final state

    tInd = t:t+deltaT_cntr/deltaT_sim-1;
    
    % Per user outputs
    yt.Estor(:,tInd) = y.Estor;
    yt.Pu(:,tInd) = y.Pu;
    yt.P(:,tInd) = y.P;
    yt.l2(:,tInd) = y.l; % Actual load limit (includes adjustment for blackout)
    yt.Pw(:,tInd) = y.Pw;
    yt.Pg(:,tInd) = y.Pg;
    yt.chi(:,tInd) = y.chi;
    yt.ci(:,tInd) = y.ci;
    yt.l(:,tInd) = u.l*ones(1,deltaT_cntr/deltaT_sim);
    yt.Pinj(:,tInd) = u.Pinj*ones(1,deltaT_cntr/deltaT_sim);
    yt.availability(:,tInd) = y.availability;
    % Add more outputs per user here
    
    % System outputs
    yt.xi(tInd) = y.xi;
    yt.deltaOmega(tInd) = y.deltaOmega;
    % Add more system outputs here
    
    x = xf;
end
xf = x;