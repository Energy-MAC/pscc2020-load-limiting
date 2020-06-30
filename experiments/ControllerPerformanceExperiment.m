classdef ControllerPerformanceExperiment < Experiment
    %CONTROLLERPERFORMANCEEXPERIMENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        Controllers
        % Pair of metricName, metricFun. The metric functions must be
        % defined below as a static method. The metric function must return
        % a scalar value.
        Metrics = {...
            'Objective', @ControllerPerformanceExperiment.metricObjectiveFore; % Objective value (on forecast time scale)
            'ObjectivePred', @ControllerPerformanceExperiment.metricObjectivePred; % Predicted objective value
            'ObjectivePost', @ControllerPerformanceExperiment.metricObjectivePost; % A posterior objective value (different than above; above computed for each time step, this computed over look-ahead window)
            'UserUtility', @ControllerPerformanceExperiment.metricUserUtility; % Realized total user utility (value - cost)
            'InterruptionCost', @ControllerPerformanceExperiment.metricInterruptionCost; % Customer interruption cost
            'CompletedValue', @ControllerPerformanceExperiment.metricCompletedValue; % Customer completed value
            'NegativeInterruptionCost', @ControllerPerformanceExperiment.metricNegativeInterruptionCost;
            'Interruptions', @ControllerPerformanceExperiment.metricInterruptions; % Number of customer interruptions
            'ASAI', @ControllerPerformanceExperiment.metricASAI; % Average Service Availability Index (ASAI)
            'MeanLoad', @ControllerPerformanceExperiment.metricMeanLoad; % Mean load per user (kW)
            'AverageLoadLimit', @ControllerPerformanceExperiment.metricAverageLoadLimit; % Mean load limit when in place
            'AverageLoadLimitFrequency', @ControllerPerformanceExperiment.metricAverageLoadLimitFrequency; % Fraction of time there is a load limit in place
            }
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
            
            % Read controller names
            t = readtable(sprintf('%scontrollers.csv',obj.CaseFolder));
            obj.Controllers = t.Properties.VariableNames;
            
            % Read specific parameters defining the Zola Infinity units, TM
            derParams = readKeyValue(sprintf('%scommon/der.csv',obj.GlobalDataFolder)); % readKeyValue defined in computational-experiment-matlab
            
            % Hard-coded parameter
            solarDataFile = sprintf('%scommon/solar/solar_ghi_data.mat',obj.GlobalDataFolder);
            
            % Programmatically generate additional parameters

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
            forecasts = struct;
            disturbances = struct;
            
            % Choose random start day
            startDay = 4+randi(361-p.T_experiment);
            
            p.startDay = startDay;
            [nPV,nBatteries] = assignCapacity(p);
            % Create users without DERs to simulate load and assign DERs
            %userTable = createUserTable(p.N,p.userTypes);
            userParams = struct;
            userParams.N = p.N;
            userParams.userTypes = p.userTypes;
            userParams.NBatteries = nBatteries;
            userParams.NPV = nPV;
            userParams.BatteryUnitCapacity = p.derParams.batteryEnergyCap*1000;
            userParams.PVUnitCapacity = p.derParams.solarInverterCap*1000;
            
            % Get the forecast and disturbances
            foreParams = struct;
            foreParams.startDay = startDay;
            foreParams.T_experiment = p.T_experiment;
            foreParams.deltaT_sim = p.deltaT_sim;
            foreParams.deltaT_hor = p.deltaT_cntr;
            foreParams.max_load_tstep = p.max_load_tstep;
            [forecasts.Pl, forecasts.Pg, disturbances.irradiance, forecasts.ps] = ...
                forecast(userParams,p.S,foreParams,p.solarDataFile);
            
            % Assign variables into return struct
            confoundingVars.startDay = startDay;
            confoundingVars.forecasts = forecasts;
            confoundingVars.disturbances = disturbances;
            confoundingVars.userParams = userParams;
        end
        
        % Generate treatment variables. These are enumerated and compared
        % within each trial.
        function treatmentVars = generateTreatmentVariables(obj,confoundingVars)
            treatmentVars = obj.Controllers;
        end
        
        % Simulate a trial
        function results = simulateTreatment(obj,confoundingVars,treatmentVars)
            
            import MicrogridDispatchSimulator.DataParsing.createUsers
            import MicrogridDispatchSimulator.Models.Microgrid
            import MicrogridDispatchSimulator.Simulation.simRHC
            
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
            
            % Create users with DERs and initialize activities
            users = createUsers(confoundingVars.userParams);
            for i = 1:length(users)
                users(i).createActivities(p.T_experiment*24*3600,p.deltaT_sim);
            end
            
            % Set parameters for the microgrid
            microgridParams.UserMaxLoad = p.Pl_max*1000;
            microgridParams.ERestart = p.E_restart;
            microgridParams.BatteryChargeRate = p.derParams.batteryInverterCap/p.derParams.batteryEnergyCap;
            microgridParams.Beta = p.derParams.beta;
            microgridParams.BusMaxInjection = p.P_max*1000;
            
            % Create and initialize the microgrid
            microgrid = Microgrid(microgridParams);
            
            microgrid.Users = users; % Connect the users
            microgrid.initialize();
            
            % Set up time param struct
            timeParams = struct;
            timeParams.T = p.T_experiment*24*3600/p.deltaT_sim;
            timeParams.deltaT_sim = p.deltaT_sim;
            timeParams.deltaT_cntr = p.deltaT_cntr;
            timeParams.deltaT_hor = p.deltaT_cntr;
            timeParams.T_hor = p.T_hor; % Number of control time steps
            
            % Set up control param struct
            controlParams = struct;
            controlParams.loadControllerName = controllerName;
            controlParams.K = p.K;
            
            % Run the simulation
            results = simRHC(microgrid,timeParams,controlParams,disturbances,forecasts,true);
        end
        
    end
    
    methods (Static)
        % Compute the objective value for the outcome power consumption
        % time series Pu on the simulation time scale.
        function x = metricObjective(outputs,expParams,trial)
            Pl = outputs.Pl/1000; % Convert to kW
            Pl_max = trial.confoundingVariables.Pl_max;
            T = size(Pl,2);
            x = Pl(:)'*kron(diag(1./Pl_max/2),speye(T))*Pl(:)-sum(Pl(:));
            x = -x/length(Pl_max)/T; % Change sign (objective was to minimize negative value) and normalize per user per time step
        end
        
        % Compute the objective value for the outcome power consumption
        % time series Pu on the forecast time scale.
        function x = metricObjectiveFore(outputs,expParams,trial)
            deltaT_hor = expParams.deltaT_cntr;
            Pl = MicrogridDispatchSimulator.Utilities.resampleBasic(outputs.Pl',expParams.deltaT_sim,deltaT_hor)';
            Pl = Pl/1000; % Convert to kW
            Pl_max = expParams.Pl_max*ones(size(Pl,1),1);
            T = size(Pl,2);
            x = Pl(:)'*kron(diag(1./Pl_max/2),speye(T))*Pl(:)-sum(Pl(:));
            x = -x/length(Pl_max)/T; % Change sign (objective was to minimize negative value) and normalize per user per time step
        end
        
        % Compute the predicted objective value
        function x = metricObjectivePred(outputs,expParams,trial)
            T_hor = expParams.T_hor;
            b = outputs.objPred/T_hor;
            T = length(b);
            x = sum(b(1:end-T_hor));
            x = x+sum(b(end-T_hor+1:end)'.*(1:T_hor));
            x = x/T;
            %x = x/size(outputs.objPred,1); already normalized by 1
        end
        
        function x = metricObjectivePost(outputs,expParams,trial)
            T_hor = expParams.T_hor; % Number of time steps in the look ahead window
            % Get the observed load on the forecast time scale
            deltaT_hor = expParams.deltaT_cntr;
            Pl = MicrogridDispatchSimulator.Utilities.resampleBasic(outputs.Pl',expParams.deltaT_sim,deltaT_hor)';
            Pl = Pl/1000; % Convert to kW
            
            Pl_max = expParams.Pl_max*ones(size(Pl,1),1); % Parameter for computing cost
            T = size(Pl,2); % Total number of time steps
            
            % When computing the objective over the forecast time horizon
            % as a running sum, the consumption at t = 1 only gets counted
            % onece, the consumption at t = 2 gets counted twice, and so on
            % until t = T_hor. From T_hor until the end, those consumptions
            % will get counted T_hor times.
            Pl1 = Pl(:,T_hor+1:end);
            T1 = T-T_hor;
            x = Pl1(:)'*kron(diag(1./Pl_max/2),speye(T1))*Pl1(:)-sum(Pl1(:));
            for t = 1:T_hor
                x = x+sum((Pl(:,t)./Pl_max/2).^2-Pl(:,t));
            end
            x = -x/T/size(Pl,1);
        end
        
        % Compute the mean customer interruption cost for all Users.
        % Normalize to cost per hour per user
        function x = metricInterruptionCost(outputs,expParams,trial)
            x = mean([outputs.Users.InterruptedCost])/expParams.T_experiment/24;
        end
        
        % Compute the negative customer interruption cost for all Users.
        % Same as above, just the negative for display purposes.
        % Normalize to cost per hour per user
        function x = metricNegativeInterruptionCost(outputs,expParams,trial)
            x = mean([outputs.Users.InterruptedCost])/expParams.T_experiment/24;
        end
        
        % Compute the mean customer activity value for all Users.
        % Normalize to cost per hour per user
        function x = metricCompletedValue(outputs,expParams,trial)
            x = mean([outputs.Users.CompletedValue])/expParams.T_experiment/24;
        end
        
        % Compute mean number of activity interruptions for all Users
        % Normalize to per day
        function x = metricInterruptions(outputs,expParams,trial)
            x = mean([outputs.Users.ActivityInterruptions])/expParams.T_experiment;
        end
        
        % Mean load (kW)
        function x = metricMeanLoad(outputs,expParams,trial)
            x = mean(outputs.Pl(:))/1000;
        end
        
        % Compute total utility gained across users. Normalize to utility
        % per hour per user.
        function x = metricUserUtility(outputs,expParams,trial)
            x = 0;
            N = length(outputs.Users);
            for n = 1:N
                x = x + outputs.Users(n).TotalUtility;
            end
            x = x/expParams.T_experiment/24/N;
        end
        
        % Compute standard ASAI
        function x = metricASAI(outputs,expParams,trial)
            %x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0);
            x = 1-mean(outputs.xi);
        end
        
        % Compute ASAI of at least 100 W available
        function x = metricASAI100(outputs,expParams,trial)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0.1);
        end
        
        % Compute ASAI of at least 500 W available
        function x = metricASAI500(outputs,expParams,trial)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,0.5);
        end
        
        % Compute ASAI of at least 1000 W available
        function x = metricASAI1000(outputs,expParams,trial)
            x = ControllerPerformanceExperiment.metricASAICapacity(outputs.timeseries.l2,outputs.timeseries.xi,1);
        end
        
        % Compute ASAI of at least 2000 W available
        function x = metricASAI2000(outputs,expParams,trial)
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
        
        % Average load limit across all customers and time steps,
        % conditional upon there being a load limit in place. 
        function x = metricAverageLoadLimit(outputs,expParams,trial)
            l = outputs.l(:); % l is in Wh
            x = mean(l(l < inf))*3600/expParams.deltaT_cntr/1000; % Convert to kW
        end
        
        % Fraction of time there is a load limit in place
        function x = metricAverageLoadLimitFrequency(outputs,expParams,trial)
            l = outputs.l(:);
            x = 1-mean(isinf(l)); % 1 minus the fraction of time there is no load limit is the fraction of time there is a limit
        end
    end
    
end

