function hdr = baseHeader(nChan, varargin)
% bvrftest.baseHeader - Minimal valid BVRF header struct for synthetic tests.
%
%   hdr = bvrftest.baseHeader(nChan, 'key', value, ...)
%
% Keys:
%   'Precision'        - NumericDataType ('Int16' (default), 'Int32', 'Single', 'Double')
%   'Srate'            - sampling rate in Hz (default 100)
%   'ParticipantIds'   - 1 x nChan cellstr with each channel's ParticipantId.
%                        '' marks a channel common to all participants.
%                        When given, a 'Participants' section is added.
%                        Default {} (single participant, no Participants section).
%   'ResolutionPerBit' - scalar added to every channel (default: field omitted)
%   'Coordinates'      - nChan x 3 electrode coordinates; adds an 'Electrodes'
%                        section (default: none)
%   'CoordSys'         - EEGCoordinateSystem value (default: section omitted)
%
% Channels are named Ch1..ChN, type EEG, with Composition.Plus pointing to the
% electrode of the same name. Arrays are stored as cell arrays so that
% jsonencode always writes JSON arrays (even with one element).

p = inputParser;
p.addParameter('Precision', 'Int16');
p.addParameter('Srate', 100);
p.addParameter('ParticipantIds', {});
p.addParameter('ResolutionPerBit', []);
p.addParameter('Coordinates', []);
p.addParameter('CoordSys', '');
p.parse(varargin{:});
o = p.Results;

hdr = struct();
hdr.BVRF           = struct('Version', '1.0.0');
hdr.BVRFHeaderFile = struct('Version', '1.0.0');

if ~isempty(o.ParticipantIds)
    ids = unique(o.ParticipantIds(~cellfun('isempty', o.ParticipantIds)), 'stable');
    parts = cell(1, numel(ids));
    for k = 1:numel(ids)
        parts{k} = struct('Id', ids{k});
    end
    % Real recordings carry participant-specific optional fields, which makes
    % jsondecode return a cell array. Mirror that here; see the dedicated test
    % for participants that all have identical fields.
    parts{end}.HeadCircumferenceInCentiMeter = 58;
    hdr.Participants = parts;
end

mod = struct();
mod.BVRFFiles.DataFile   = struct('Version', '1.0.0', ...
    'NumericDataType', o.Precision, 'ChannelCount', nChan);
mod.BVRFFiles.MarkerFile = struct('Version', '1.0.0');
mod.DataSpecific = struct('SamplingFrequencyInHertz', o.Srate);

if ~isempty(o.CoordSys)
    mod.CoordinateSystems = struct('EEGCoordinateSystem', o.CoordSys, ...
        'EEGCoordinateUnit', 'MM');
end

if ~isempty(o.Coordinates)
    el = cell(1, nChan);
    for k = 1:nChan
        el{k} = struct('Name', sprintf('Ch%d', k), 'Coordinates', o.Coordinates(k, :));
    end
    mod.Electrodes = el;
end

channels = cell(1, nChan);
for k = 1:nChan
    ch = struct();
    if ~isempty(o.ParticipantIds) && ~isempty(o.ParticipantIds{k})
        ch.ParticipantId = o.ParticipantIds{k};
    end
    ch.Name = sprintf('Ch%d', k);
    ch.Type = 'EEG';
    ch.Unit = 'uV';
    if ~isempty(o.ResolutionPerBit)
        ch.ResolutionPerBit = o.ResolutionPerBit;
    end
    ch.Composition = struct('Plus', struct('Name', ch.Name));
    channels{k} = ch;
end
mod.Channels = channels;

hdr.EEGModality = mod;
end
