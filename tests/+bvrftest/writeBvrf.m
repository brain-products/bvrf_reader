function hdrFile = writeBvrf(folder, name, hdr, data, varargin)
% bvrftest.writeBvrf - Write a synthetic BVRF file set for tests.
%
%   hdrFile = bvrftest.writeBvrf(folder, name, hdr, data, 'key', value, ...)
%
% Inputs:
%   folder - output folder (normally a TemporaryFolderFixture folder)
%   name   - base file name (no extension)
%   hdr    - header struct, written as JSON to <name>.bvrh
%   data   - [channels x samples] raw numeric values, written interleaved
%            (sample-major) little-endian to <name>.bvrd using the header's
%            NumericDataType. Pass [] to skip writing the data file.
%
% Keys:
%   'Markers'         - cell array; row 1 = column names, other rows = values
%                       (all char). Written tab-separated to <name>.bvrm.
%   'Impedances'      - cellstr of raw lines, written to <name>.bvri.
%   'TrailingValues'  - extra raw values appended to the .bvrd file
%                       (to simulate a truncated last frame). Default [].
%
% Output:
%   hdrFile - full path of the written .bvrh file.

p = inputParser;
p.addParameter('Markers', {});
p.addParameter('Impedances', {});
p.addParameter('TrailingValues', []);
p.parse(varargin{:});
o = p.Results;

hdrFile = fullfile(folder, [name '.bvrh']);
writeText(hdrFile, jsonencode(hdr, 'PrettyPrint', true));

if ~isempty(data)
    precision = lower(hdr.EEGModality.BVRFFiles.DataFile.NumericDataType);
    fid = fopen(fullfile(folder, [name '.bvrd']), 'w', 'ieee-le');
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, data(:), precision);
    if ~isempty(o.TrailingValues)
        fwrite(fid, o.TrailingValues(:), precision);
    end
    clear cleaner
end

if ~isempty(o.Markers)
    rows = cell(size(o.Markers, 1), 1);
    for r = 1:size(o.Markers, 1)
        rows{r} = strjoin(o.Markers(r, :), sprintf('\t'));
    end
    writeText(fullfile(folder, [name '.bvrm']), strjoin(rows, newline));
end

if ~isempty(o.Impedances)
    writeText(fullfile(folder, [name '.bvri']), strjoin(o.Impedances, newline));
end
end

function writeText(file, txt)
fid = fopen(file, 'w', 'n', 'UTF-8');
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, '%s', txt);
end
