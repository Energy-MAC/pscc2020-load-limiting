
clc
clearvars
dbstop if error;
%%

% globalDataFolder='inputs/';
% uG = create_uG(globalDataFolder,'test',365,1);
% save('out/uG.mat','uG');

load('out/uG.mat') 

simSamples=24*3600;
tStart=(24*20+13)*3600; % in seconds since 00:00:00 of January first

ctl.maxLoad=10000*ones(simSamples,length(uG.user)); % maximum load in W
ctl.pSet=zeros(simSamples,length(uG.user));
ctl.qSet=zeros(simSamples,length(uG.user));

tic;
[allInterrupts,P,loadPower,battWh,uG]=simOp(tStart,uG,ctl);
toc;

%% Test the counterparts of 
tic;
[allInterrupts1,P1,loadPower1,battWh1,uG1]=simOp_v2(tStart,uG,ctl);
toc;

tic;
loadOnly = simLoad(tStart,uG,simSamples);
toc;

%% Compare
subplot(311);
plot(loadPower);
title('Original simOp');
subplot(312);
plot(loadPower1);
title('factored out simOp');
subplot(313);
plot(loadOnly);
title('loadSim');