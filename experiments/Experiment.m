classdef Experiment < handle
    %EXPERIMENT Abstract class for defining experiments
    %   Detailed explanation goes here
    
    properties (SetAccess = protected, GetAccess = public)
        ExperimentParams
    end
    
    properties (SetAccess = private, GetAccess = public)
        CaseFolder
        ExperimentName
        GlobalDataFolder = 'data/';
        NTrials
        ResultsFolder
    end
    
    properties (Access = private)
        RandStreamTrials
        RandStreamExperiment
        tStruct = struct('confoundingVariables',[],'treatmentVariables',[],'outputs',[]); % Model for trial structure; could be another class
    end
    
    properties (Abstract, SetAccess = protected, GetAccess = public)
    end
    
    methods
        
        % Constructor: experimentName and globalDataFolder as path to data
        % directory are required. A caseName is optional to specify a
        % particular case of this experiment.
        function obj = Experiment(experimentName,args)
            if (nargin < 2)
                args = struct;
            end
            
            obj.ExperimentName = experimentName;
            
            % Set up directory structure
            if ~isfield(args,'caseName')
                obj.ResultsFolder = sprintf('%sexperiments/outputs/%s/',obj.GlobalDataFolder,obj.ExperimentName);
                obj.CaseFolder = sprintf('%sexperiments/inputs/%s/',obj.GlobalDataFolder,obj.ExperimentName);
            else
                caseName = args.caseName;
                obj.ResultsFolder = sprintf('%sexperiments/outputs/%s/%s/',obj.GlobalDataFolder,obj.ExperimentName,caseName);
                obj.CaseFolder = sprintf('%sexperiments/inputs/%s/%s/',obj.GlobalDataFolder,obj.ExperimentName,caseName);
            end
                
            if ~exist(obj.ResultsFolder,'dir')
                mkdir(obj.ResultsFolder);
            end
            if ~exist(sprintf('%strials/',obj.ResultsFolder),'dir')
                mkdir(sprintf('%strials/',obj.ResultsFolder));
            end
            
            % Get the number of trials to run
            p = readKeyValue(sprintf('%skey_values.csv',obj.CaseFolder));
            obj.NTrials = p.N_trials;
            
            % Set up the random number generation and streams for each
            % trial
            seed = p.seed;
            streams = RandStream.create('mrg32k3a','Seed',seed,'NumStreams',obj.NTrials+1,'CellOutput',true);
            obj.RandStreamExperiment = streams{1}; % First one is for experiment setup
            obj.RandStreamTrials = streams(2:end); % Second is for each trial
            
            % Remove those properties and set the rest as experiment
            % parameters
            p = rmfield(p,'N_trials');
            p = rmfield(p,'seed');
            obj.ExperimentParams = p;
            
            % Seed rng for setting up additional parameters
            RandStream.setGlobalStream(obj.RandStreamExperiment);
            if (isfield(args,'setupArgs'))
                setupArgs = args.setupArgs;
            else
                setupArgs = struct;
            end
            obj.setupAdditionalParameters(setupArgs);
        end
        
        % Run the experiment either with trials in parallel or series
        function trials = runExperiment(obj,order)
            if nargin < 2
                order = 'par';
            end
            switch lower(order)
                case 'par'
                    trials = obj.runTrialsPar(true);
                case 'ser'
                    trials = obj.runTrialsSerFrom();
                otherwise
                    error('Unrecognized execution order');
            end
        end
        
        function trials = runTrialsSerFrom(obj,startTrial,endTrial)
            if nargin < 2
                startTrial = 1;
            end
            if nargin < 3
                endTrial = obj.NTrials;
            end
            
            fprintf('Running %s in series starting from trial %i\r',obj.ExperimentName,startTrial);
            if (startTrial > 1)
                % Get trials that were previously saved
            end
            
            for i = startTrial:endTrial
                try
                    t = obj.runTrial(i);
                    if (isempty(t.outputs))
                        warning('A completed trial should assign outputs')
                    end
                    obj.saveTrial(i,t);
                catch ME
                    warning('An error was encountered running trial %i. Skipping it. Error message was %s',i,ME.message);
                end
            end
            trials = obj.loadAllTrials();
        end
        
        function trials = runTrialsPar(obj,overwrite)
            % Get an array of trials struct
            fprintf('Running %s in parallel with %i trials. Overwriting any saved: %s\r',obj.ExperimentName,obj.NTrials,mat2str(overwrite));
            
            % Model for trial structure
            tStruct = obj.tStruct;
            
            % Functions to call within par loop
            loadTrialFun = @obj.loadTrial;
            saveTrialFun = @obj.saveTrial;
            runTrialFun = @obj.runTrial;
            
            % Run trials
            parfor i = 1:obj.NTrials
                if (overwrite)
                    % Create a fresh one
                    trial = tStruct;
                else
                    % Try and load
                    trial = feval(loadTrialFun,i);
                    if isempty(trial)
                        % Couldn't load a saved one so create fresh
                        trial = tStruct;
                    end
                end
                
                if (isempty(trial.outputs)) % Will be true for fresh trials
                    try
                        t = feval(runTrialFun,i);
                        if (isempty(t.outputs))
                            warning('A completed trial should assign outputs')
                        end
                        trial = t;
                        feval(saveTrialFun,i,trial);
                    catch ME
                        warning('An error was encountered running trial %i. Skipping it. Error message was %s',i,ME.message);
                    end
                else
                    fprintf('Trial %i already completed\n',i);
                end
            end
            fprintf('Completed all trials. Loading results...');
            trials = obj.loadAllTrials();
            fprintf('...done\n');
        end
        
        function trial = runTrial(obj,i)
            fprintf('Starting trial %i...\n',i);
            % Requires that obj.loadExperimentParameters has been called
            % first
            
            % Set the stream for this trial
            RandStream.setGlobalStream(obj.RandStreamTrials{i});
            
            tTrial = tic; % Time the trial
            trial = struct;
            fprintf('Generating confounding variables for trial %i...\n',i);
            tDataProcess = tic;
            trial.confoundingVariables = obj.generateConfoundingVariables(i); % Returns struct
            fprintf('...confounding variables generated for trial %i. Data processing took %g seconds\n',i,toc(tDataProcess));
            trial.treatmentVariables = obj.generateTreatmentVariables(trial.confoundingVariables); % Returns struct array
            for j = 1:length(trial.treatmentVariables)
                fprintf('Simulating treatment %i of %i for trial %i...\n',j,length(trial.treatmentVariables),i);
                % Simulation
                tSim = tic; % Time the simulation with the treatment
                trial.outputs(j) = obj.simulateTrial(trial.confoundingVariables,trial.treatmentVariables(j));
                fprintf('...done simulating treatment %i of %i for trial %i. Elapsed time: %g seconds\n',j,length(trial.treatmentVariables),i,toc(tSim));
            end
            fprintf('...trial %i completed. Elapsed time for trial: %g seconds\n',i,toc(tTrial));
        end
        
        function trial = loadTrial(obj,i)
            try
                t = load(sprintf('%strials/%i',obj.ResultsFolder,i),'trial');
                trial = t.trial;
            catch
                trial = [];
            end
        end
        
        function [trials,indCompleted] = loadAllTrials(obj)
            indCompleted = false(1,obj.NTrials);
            for i = 1:obj.NTrials
                t = obj.loadTrial(i);
                if (~isempty(t) && ~isempty(t.outputs))
                    trials(i) = t;
                    indCompleted(i) = true;
                else
                    trials(i) = obj.tStruct;
                end
            end
        end
        
        function [trials] = loadCompletedTrials(obj)
            [trials,indCompleted] = obj.loadAllTrials();
            trials = trials(indCompleted);
        end
        
        function saveTrial(obj,i,trial)
            save(sprintf('%strials/%i',obj.ResultsFolder,i),'trial');
        end
        
        function resultsDist = computeResultsDistribution(obj,metricFun,passTrial)
            if (nargin < 3)
                passTrial = false; % Optional flag to request that the whole trial info (i.e. confounding and experiment params) be passed to compute the metric.
            end
            
            trials = obj.loadCompletedTrials();
            
            % Infer the number of trials and treatments in each trial
            Ntrials = length(trials); % Number of trials
            if ~Ntrials
                resultsDist = [];
                return;
            end
            Ntreats = length(trials(1).treatmentVariables); % Number of treatments; assumes all trials have the same treatments
            
            % Preallocate a matrix for the results for each trial and
            % treatment. It will be Ntrials x Ntreats and the i,j element
            % will be a performance metric for that combination
            resultsDist = nan(Ntrials,Ntreats);
            
            % Compute the performance metric for each outcome
            for i = 1:Ntrials
                if (length(trials(i).outputs) < Ntreats)
                    % Not all outputs were computed for each treatment for this trial
                    continue
                end
                for j = 1:Ntreats
                    % Compute the metric for that treatment
                    if (passTrial)
                        resultsDist(i,j) = metricFun(trials(i).outputs(j),obj.ExperimentParams,trials(i));
                    else
                        resultsDist(i,j) = metricFun(trials(i).outputs(j),obj.ExperimentParams);
                    end
                end
            end
        end
        
        function setupAdditionalParameters(obj,setupArgs)
        end
    end
    
    methods (Abstract)
        
        % Generate confounding variables
        generateConfoundingVariables(obj,trialInd)
        
        % Generate treatment variables
        generateTreatmentVariables(obj,confoundingVariables)
        
        % Simulate a trial
        simulateTrial(obj,confoundingVariables,treatmentVariables)
    end
end

