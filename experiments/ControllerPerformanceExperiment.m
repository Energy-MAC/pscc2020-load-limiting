classdef ControllerPerformanceExperiment < Experiment
    %CONTROLLERPERFORMANCEEXPERIMENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        Results
        Controllers
    end
    
    methods
        function obj = ControllerPerformanceExperiment(caseName)
            %CONTROLLERPERFORMANCE Construct an instance of this class
            args = struct;
            if nargin > 0
                args.caseName = caseName;
            end
            obj@Experiment('controllerPerformance',args);
            
        end
        
        % Programmatically read / generate additional parameters
        function setupAdditionalParameters(obj,setupArgs)

            % Shorthand variable for general key-value parameters
            p = obj.ExperimentParams;
            
            t = readtable(sprintf('%scontrollers.csv',obj.CaseFolder));
            obj.Controllers = t.Properties.VariableNames;
            
            % Read specific parameters defining the Zola Infinity units, TM
            infParams = readKeyValue(sprintf('%scommon/infinity.csv',obj.GlobalDataFolder));
            
            % Hard-coded parameter
            solarDataFile = sprintf('%scommon/solar/solar_ghi_data.mat',obj.GlobalDataFolder);
            
            % Programmatically generate additional parameters

            % Read components of the microgrid from files...
            % Get model for user types
            userTypes = loadUserTypes(obj.GlobalDataFolder);
            
            obj.ExperimentParams.infParams = infParams;
            obj.ExperimentParams.userTypes = userTypes;
            obj.ExperimentParams.solarDataFile = solarDataFile;
        end
        
        % Generate confounding variables, in the sense of multiple
        % 'control' groups across trials. These are generated for each
        % trial.
        function confoundingVars = generateConfoundingVariables(obj,trialInd)
            p = obj.ExperimentParams;
            
            uG = struct;
            uG.userType = p.userTypes;
            
            % Define structs
            confoundingVars = struct;
            forecasts = struct;
            disturbances = struct;
            
            % Choose random start day
            confoundingVars.startDay = 4+randi(361-p.T_experiment);
            p.startDay = confoundingVars.startDay;
            
            
            % Get the common daily and hourly data
            [dailyTable,hourlyTable] = loadTimeTables(obj.GlobalDataFolder,p.T_experiment,confoundingVars.startDay);

            userTable = createUserTable(p.N,uG.userType);
            userTable = assignCapacity(userTable,p,p.infParams,uG.userType,dailyTable,hourlyTable,p.solarDataFile);
            
            uG.user = getUserStruct(userTable);
            uG.dailyTable = dailyTable;
            uG.hourlyTable = hourlyTable;

            confoundingVars.E_max = p.infParams.batteryEnergyCap*[uG.user.nBatt]'; % Battery capacity of each user, kWh, Nx1 vector
            confoundingVars.Pc_max = p.infParams.batteryInverterCap*[uG.user.nBatt]'; % Maximum charge / discharge power of each battery; kW
            
            confoundingVars.Pl_max = p.Pl_max*ones(length(uG.user),1);  % Maximum possible load of each user, kW, Nx1 vector. JL: Make this experiment param for now. Could be computed in different ways from network data or user type. It's something that the operator has access to.
            confoundingVars.P_max = p.P_max*ones(length(uG.user),1); % Max power at connection. Could be same as max load, or different. Should be defined at network level.
            
            foreParams = struct;
            foreParams.startDay = p.startDay;
            foreParams.T_experiment = p.T_experiment;
            foreParams.deltaT_sim = p.deltaT_sim;
            foreParams.deltaT_hor = p.deltaT_hor;
            foreParams.max_load_tstep = p.max_load_tstep;
            foreParams.N = p.N;
            
            
            % Get the forecast and disturbances
            [forecasts.Pl, forecasts.Pg, disturbances.irradiance] = ...
                forecast(uG,p.S,foreParams,p.infParams,p.solarDataFile);
            disturbances.ambientTemp = getAmbientTemp(uG.hourlyTable,p.deltaT_sim);
            
            
            %% Initial conditions
            uGState = createInitialState(uG.user,uG.userType,uG.dailyTable{:,'type'},confoundingVars.E_max,p.randomizeEstor0);
            
            
            % Assign variables into return struct
            confoundingVars.forecasts = forecasts;
            confoundingVars.disturbances = disturbances;
            confoundingVars.uGState = uGState;
            confoundingVars.uG = uG;
        end
        
        % Generate treatment variables. These are enumerated and compared
        % within each trial.
        function treatmentVars = generateTreatmentVariables(obj,confoundingVars)
            treatmentVars = obj.Controllers;
        end
        
        % Simulate a trial
        function results = simulateTrial(obj,confoundingVars,treatmentVars)
            % Define return struct
            results = struct;
            
            % The treatment variable defines the controller
            controllerName = treatmentVars{1};
            
            % The confounding variables define the forecasts and
            % disturbances
            disturbances = confoundingVars.disturbances;
            try
                % Forecasts may not be defined depending on the controller
                forecasts = confoundingVars.forecasts;
            catch
                forecasts = [];
            end

            % Set up the params and initial state from confounding variables
            p = obj.ExperimentParams;
            p.uG = confoundingVars.uG;
            p.infParams = obj.ExperimentParams.infParams;
            p.E_max = confoundingVars.E_max;
            p.Pc_max = confoundingVars.Pc_max;
            p.Pl_max = confoundingVars.Pl_max;
            p.P_max = confoundingVars.P_max;
            
            x0 = confoundingVars.uGState; % State
            x0.gamma = ones(p.N,1);
            
            [yt, xf] = simRHC(p,x0,controllerName,disturbances,forecasts);
            results.timeseries = yt;
            results.finalState = xf;
        end
        
    end
    
    methods (Static)
        % Compute the objective value for the outcome power consumption
        % time series Pu on the simulation time scale.
        function x = metricObjective(outputs,expParams,trial)
            Pu = outputs.timeseries.Pu;
            Pl_max = trial.confoundingVariables.Pl_max;
            T = size(Pu,2);
            x = Pu(:)'*kron(diag(1./Pl_max/2),eye(T))*Pu(:)-sum(Pu(:));
        end
        
        % Compute the objective value for the outcome power consumption
        % time series Pu on the forecast time scale.
        function x = metricObjectiveFore(outputs,expParams,trial)
            Pu = resampleBasic(outputs.timeseries.Pu',expParams.deltaT_sim,expParams.deltaT_hor)';
            Pl_max = trial.confoundingVariables.Pl_max;
            T = size(Pu,2);
            x = Pu(:)'*kron(diag(1./Pl_max/2),eye(T))*Pu(:)-sum(Pu(:));
        end
        
        % Compute the total customer interruption cost from the timeseries
        % variable ci
        function x = metricInterruptionCost(outputs,expParams)
            x = sum(outputs.timeseries.ci(:));
        end
        
        % Compute total number of activity interruptions from the
        % timeseries variable chi
        function x = metricInterruptions(outputs,expPararams)
            x = sum(outputs.timeseries.chi(:));
        end
        
        % Compute standard ASAI
        function x = metricASAI(outputs,expParams)
            %x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0);
            x = mean(mean(outputs.timeseries.availability));
        end
        
        % Compute ASAI of at least 100 W available
        function x = metricASAI100(outputs,expParams)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0.1);
        end
        
        % Compute ASAI of at least 500 W available
        function x = metricASAI500(outputs,expParams)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0.5);
        end
        
        % Compute ASAI of at least 1000 W available
        function x = metricASAI1000(outputs,expParams)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,1);
        end
        
        % Compute ASAI of at least 2000 W available
        function x = metricASAI2000(outputs,expParams)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,2);
        end
        
        % Function to calculate the Average Service Availability Index of a
        % given capacity.
        function x = metricASAICapacity(l,xi,capacity)
            %l: load limit signal, should be the one adjusted for any
            %blackout
            %xi: blackout signal; binary, 1 => blackout
            %scalar capacity threshold
            t = (l >= capacity) & repmat(~xi',size(l,1),1); % matrix; each row corresponds to user. If element is 1, means that user had capacity available of at least the limit
            x = mean(t(:));
        end
    end
    
end

