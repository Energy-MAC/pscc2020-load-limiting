function temp = getAmbientTemp(hourlyTable,resolution)
%GETAMBIENTTEMP Summary of this function goes here
%   Detailed explanation goes here
temp = resampleBasic(hourlyTable{:,{'temp'}},3600,resolution);
end

