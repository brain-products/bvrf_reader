clear all
clc
folder = 'C:\Users\alejandro.ojeda\Documents\Data\BVRF\2025-11-18_Data-in-new-format\Data\';
files = dir([folder '*.bvrh']);
headerFiles = {files.name};

for i=1:length(headerFiles)

    hdrFile = fullfile(folder, headerFiles{i});
    [hdr, participantId, data, channels, markers, impedance] = loadbvrf(hdrFile, [], false, true);
    
end
