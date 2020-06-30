%% File system management

try
    % Look for local config
    params = config();
catch
    % Use default if local not defined
    params = configDefault();
end

% Import computational experiment superclass and utilities
addpath(params.experimentDir);
addpath(sprintf('%s/%s',params.experimentDir,'utils'));

% Import microgrid simulator
addpath(params.simulatorDir);

% Import local experiments and scripts
addpath('./experiments');
addpath('./scripts');

% Import local computation functions
addpath('./computation/forecast');
addpath('./computation/microgrid');

% Import local execution function
addpath('./bin');

disp('Directories added to path...Initialization complete.');