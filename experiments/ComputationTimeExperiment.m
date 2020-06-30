classdef ComputationTimeExperiment < Experiment
    %COMPUTATIONTIMEEXPERIMENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        Controllers = {'Deterministic','StochasticTrajectory','StochasticDP'}
        SampleN
        SampleT_hor
        SampleS
        Metrics = {...
            'Time',@ComputationTimeExperiment.metricTime
            }
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
            derParams = readKeyValue(sprintf('%scommon/der.csv',obj.GlobalDataFolder));
            
            t = readtable(sprintf('%ssample_N.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleN = t{:,1};
            t = readtable(sprintf('%ssample_S.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleS = t{:,1};
            t = readtable(sprintf('%ssample_T.csv',obj.CaseFolder),'ReadVariableNames',false);
            obj.SampleT_hor = t{:,1};
            
            % Hard-coded parameter
            solarDataFile = sprintf('%scommon/solar/solar_ghi_data.mat',obj.GlobalDataFolder);
            
            % Programmatically generate additional parameters
            
            obj.ExperimentParams.T_experiment = ceil(obj.SampleT_hor(end)*p.deltaT_cntr/(3600*24))*1; % T_experiment is used in the sizing for estimating load and solar. Set it to 7 times the max forecast time for a decent estimate.

            % Read components of the microgrid from files...
            % Get model for user types
            userTypeFolder = sprintf('%scommon/user_types/',obj.GlobalDataFolder);
            userTypes = MicrogridDispatchSimulator.DataParsing.loadUserTypes(userTypeFolder);
            
            obj.ExperimentParams.derParams = derParams;
            obj.ExperimentParams.userTypes = userTypes;
            obj.ExperimentParams.solarDataFile = solarDataFile;
        end
        
        % Generate confounding variables, in the sense of multiple
        % 'control' groups across trials. These are generated for each
        % trial.
        function confoundingVars = generateConfoundingVariables(obj,trialInd)
            p = obj.ExperimentParams;
            
            % Define structs
            confoundingVars = struct;
            
            % Choose random start day
            startDay = 4+randi(361-p.T_experiment);
            p.startDay = startDay;
            
            % Parameters needed for forecast
            foreParams = struct;
            foreParams.startDay = startDay;
            foreParams.T_experiment = p.T_experiment;
            foreParams.deltaT_sim = p.deltaT_sim;
            foreParams.deltaT_hor = p.deltaT_cntr;
            foreParams.max_load_tstep = p.max_load_tstep;
                        
            for i = 1:length(obj.SampleN)
                N = obj.SampleN(i);
                p.N = N;
                [nPV,nBatteries] = assignCapacity(p);
                
                % Create users
                userParams = struct;
                userParams.N = p.N;
                userParams.userTypes = p.userTypes;
                userParams.NBatteries = nBatteries;
                userParams.NPV = nPV;
                userParams.BatteryUnitCapacity = p.derParams.batteryEnergyCap*1000;
                userParams.PVUnitCapacity = p.derParams.solarInverterCap*1000;
                
                confoundingVars.userParams(i) = userParams;
                
                for j = 1:length(obj.SampleS)
                    S = obj.SampleS(j);
                    f = struct;
                    %[f.Pl, f.Pg] = forecast(uG,p.S,p,obj.ExperimentParams.infParams,obj.ExperimentParams.solarDataFile);
                    [f.Pl, f.Pg, ~, f.ps] = forecast(userParams,S,foreParams,p.solarDataFile);
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
        function results = simulateTreatment(obj,confoundingVars,treatmentVars)
            
            import MicrogridDispatchSimulator.DataParsing.createUsers
            import MicrogridDispatchSimulator.Models.Microgrid
            import MicrogridDispatchSimulator.Models.MicrogridController
            
            p = obj.ExperimentParams;
            
            % Compute params for users
            userParams = confoundingVars.userParams(treatmentVars.indN);
            users = createUsers(userParams);
            
            % Set parameters for the microgrid
            microgridParams.UserMaxLoad = p.Pl_max*1000;
            microgridParams.ERestart = 0; % Dummy param for restart threshold
            microgridParams.BatteryChargeRate = p.derParams.batteryInverterCap/p.derParams.batteryEnergyCap;
            microgridParams.Beta = 0; % Dummy param for stiffness
            microgridParams.BusMaxInjection = p.P_max*1000;
            
            % Create and initialize a microgrid for the controller
            microgrid = Microgrid(microgridParams);
            
            microgrid.Users = users; % Connect the users
            microgrid.initialize();
            
            controlParams = struct;
            controlParams.deltaT_cntr = p.deltaT_cntr;
            controlParams.deltaT_hor = p.deltaT_cntr;
            controlParams.gamma = ones(userParams.N,1);
            controlParams.K = 0; % Dummy param for computing injection setpoint
            
            microgridController = MicrogridController(microgrid,treatmentVars.controller,controlParams);
            
            % Get forecast
            forecast = confoundingVars.forecast(treatmentVars.indN,treatmentVars.indS);
            
            % Get forecast only over horizon
            T_hor = treatmentVars.T_hor;
            uMGC.W.Pg = forecast.Pg(:,1:T_hor,:);
            uMGC.W.Pl = forecast.Pl(:,1:T_hor,:);
            uMGC.W.ps = forecast.ps;
            
            % Calculate time to compute controller decision
            t = tic;
            microgridController.update(0,uMGC);
            results = toc(t);
        end
        
    end
    
    methods (Static)
        % Returns time to solve for each trial and test set
        function x = metricTime(outputs,expParams,trial)
            x = outputs;
        end
    end
    
end

