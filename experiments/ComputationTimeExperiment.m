classdef ComputationTimeExperiment < Experiment
    %COMPUTATIONTIMEEXPERIMENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        Results
        Controllers = {'Deterministic','StochasticTrajectory','StochasticDP'}
        SampleN
        SampleT_hor
        SampleS
    end
    
    methods
        function obj = ComputationTimeExperiment(caseName)
            %COMPUTATIONTIMEEXPERIMENT Construct an instance of this class
            args = struct;
            if nargin > 0
                args.caseName = caseName;
            end
            obj@Experiment('computationTime',args);
        end
        
        % Load the experiment parameters. These are constant across trials.
        % setupArgs can be used to pass variables from the constructor to
        % this function. This function gets called in the super
        % constructor.
        function setupAdditionalParameters(obj,setupArgs)
%             obj.SampleN = setupArgs.SampleN;
%             obj.SampleT_hor = setupArgs.SampleT_hor;
%             obj.SampleS = setupArgs.SampleS;

            % Shorthand variable for general key-value parameters
            p = obj.ExperimentParams;
            
            % Read specific parameters defining the Zola Infinity units, TM
            infParams = readKeyValue(sprintf('%scommon/infinity.csv',obj.GlobalDataFolder));
            
            t = readtable(sprintf('%ssample_N.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleN = t{:,1};
            t = readtable(sprintf('%ssample_S.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleS = t{:,1};
            t = readtable(sprintf('%ssample_T.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleT_hor = t{:,1};
            
            % Hard-coded parameter
            solarDataFile = sprintf('%scommon/solar/solar_ghi_data.mat',obj.GlobalDataFolder);
            
            % Programmatically generate additional parameters
            
            obj.ExperimentParams.T_experiment = ceil(obj.SampleT_hor(end)*p.deltaT_hor/(3600*24))*1; % T_experiment is used in the sizing for estimating load and solar. Set it to 7 times the max forecast time for a decent estimate.

            % Read components of the microgrid from files...
            % Get model for user types
            userTypes = loadUserTypes(obj.GlobalDataFolder);
          
            uG = struct;
            uG.userType = userTypes;
            
            obj.ExperimentParams.infParams = infParams;
            obj.ExperimentParams.uGNoUsers = uG;
            obj.ExperimentParams.solarDataFile = solarDataFile;
        end
        
        % Generate confounding variables, in the sense of multiple
        % 'control' groups across trials. These are generated for each
        % trial.
        function confoundingVars = generateConfoundingVariables(obj,trialInd)
            p = obj.ExperimentParams;
            confoundingVars = struct;
            
            confoundingVars.startDay = 4+randi(361-p.T_experiment);
            p.startDay = confoundingVars.startDay;
            
            uG = obj.ExperimentParams.uGNoUsers;
            % Get the common daily and hourly data
            [uG.dailyTable,uG.hourlyTable] = loadTimeTables(obj.GlobalDataFolder,p.T_experiment,p.startDay);
                        
            for i = 1:length(obj.SampleN)
                N = obj.SampleN(i);
                p.N = N;
                
                % Add N users to uG object
                userTable = createUserTable(N,uG.userType);
                userTable = assignCapacity(userTable,p,obj.ExperimentParams.infParams,uG.userType,uG.dailyTable,uG.hourlyTable,obj.ExperimentParams.solarDataFile);
                users = getUserStruct(userTable);

                uG.user = users;
                E_max = obj.ExperimentParams.infParams.batteryEnergyCap*[users.nBatt]';
                uGState = createInitialState(uG.user,uG.userType,uG.dailyTable{:,'type'},E_max,p.randomizeEstor0);
                
                confoundingVars.uGs(i) = uG; % Store a uG with N users
                confoundingVars.uGStates(i) = uGState;
                
                for j = 1:length(obj.SampleS)
                    p.S = obj.SampleS(j);
                    f = struct;
                    [f.Pl, f.Pg] = forecast(uG,p.S,p,obj.ExperimentParams.infParams,obj.ExperimentParams.solarDataFile);
                    
                    confoundingVars.forecast(i,j) = f; % Store a forecast with S scenarios and N users
                end
            end
        end
        
        % Generate treatment variables. These are enumerated and compared
        % within each trial.
        function treatmentVars = generateTreatmentVariables(obj,confoundingVars)
            %treatmentVars = obj.Controllers;
            treatmentVars = [];
            for c = obj.Controllers
                for i = 1:length(obj.SampleN)
                    for j = 1:length(obj.SampleS)
                        for k = 1:length(obj.SampleT_hor)
                            t.controller = c{1};
                            t.indN = i;
                            t.indS = j;
                            t.T_hor = obj.SampleT_hor(k);
                            treatmentVars = [treatmentVars;t];
                        end
                    end
                end
            end
        end
        
        % Simulate a trial
        function results = simulateTrial(obj,confoundingVars,treatmentVars)
            
            % Set up initial state
            x = confoundingVars.uGStates(treatmentVars.indN);
            N = obj.SampleN(treatmentVars.indN);
            x.gamma = ones(N,1);
            
            % Compute params for users
            users = confoundingVars.uGs(treatmentVars.indN).user;
            p = struct;
            p.K = 1; % Meaningless argument in this context
            p.E_max = obj.ExperimentParams.infParams.batteryEnergyCap*[users.nBatt]'; % Battery capacity of each user, kWh, Nx1 vector
            p.Pc_max = obj.ExperimentParams.infParams.batteryInverterCap*[users.nBatt]'; % Maximum charge / discharge power of each battery; kW
            
            p.Pl_max = obj.ExperimentParams.Pl_max*ones(length(users),1);  % Maximum possible load of each user, kW, Nx1 vector. JL: Make this experiment param for now. Could be computed in different ways from network data or user type. It's something that the operator has access to.
            p.P_max = obj.ExperimentParams.P_max*ones(length(users),1); % Max power at connection. Could be same as max load, or different. Should be defined at network level.
            
            p.deltaT_hor = obj.ExperimentParams.deltaT_hor;
            
            % Get forecast
            forecast = confoundingVars.forecast(treatmentVars.indN,treatmentVars.indS);
            
            % Get forecast only over horizon
            T_hor = treatmentVars.T_hor;
            W.Pg = forecast.Pg(:,1:T_hor,:);
            W.Pl = forecast.Pl(:,1:T_hor,:);
            W.ps = ones(size(W.Pg,3),1);
            
            % Calculate time to compute controller decision
            t = tic;
            u = getControlAction(treatmentVars.controller,x,W,p);
            results = toc(t);
        end
        
    end
    
    methods (Static)
        % Returns time to solve for each trial and test set
        function x = metricTime(outputs,expParams)
            x = outputs;
        end
    end
    
end

