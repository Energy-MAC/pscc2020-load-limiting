function solar_scaling = solarSizing(load, norm_solar, target_ratio)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
daySeconds = 60*60*24;
N_users = size(load,1);

solar_scaling = zeros(N_users, 1);
% get the daily energy (kWh)
for user=1:N_users
    load = mean(load(user,:,:),3);
    norm_solar = mean(norm_solar,2)';
    loadEnergy = resampleBasic(load, 1, daySeconds) / 3600;
    solarEnergy = resampleBasic(norm_solar, 1, daySeconds) / 3600;
    ratio = loadEnergy / solarEnergy; % get the ratio of the average daily values
    
    solar_scaling(user) = round(target_ratio/ratio);
end

