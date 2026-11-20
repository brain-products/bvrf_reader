classdef tEegLoadbvrf < matlab.unittest.TestCase
    % Unit tests for eeg_loadbvrf.m (BVRF -> EEGLAB EEG structs), using
    % synthetic BVRF files written to a temporary folder.

    properties
        Dir   % temporary folder for the current test
    end

    methods (TestClassSetup)
        function setupPath(testCase)
            bvrftest.addPaths(testCase);
        end
    end

    methods (TestMethodSetup)
        function makeTempFolder(testCase)
            f = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Dir = f.Folder;
        end
    end

    methods
        function [ALLEEG, hdr] = loadAll(testCase, varargin)
            % Load <Dir>/rec.bvrh with the given key/value options.
            [hdr, ALLEEG] = eeg_loadbvrf(testCase.Dir, 'rec.bvrh', varargin{:});
        end

        function EEG = loadOne(testCase, varargin)
            % Load and return the first (or only) EEG struct.
            ALLEEG = testCase.loadAll(varargin{:});
            EEG = ALLEEG{1};
        end

        function ev = loadEvents(testCase, varargin)
            % Load and return EEG.event of the first EEG struct.
            EEG = testCase.loadOne(varargin{:});
            ev = EEG.event;
        end

        function write(testCase, hdr, data, varargin)
            bvrftest.writeBvrf(testCase.Dir, 'rec', hdr, data, varargin{:});
        end
    end

    % =================================================================
    %  Core fields and data
    % =================================================================
    methods (Test)
        function coreFields(testCase)
            data = bvrftest.pattern(4, 50);
            testCase.write(bvrftest.baseHeader(4, 'Srate', 250), data);

            ALLEEG = testCase.loadAll();

            testCase.verifyClass(ALLEEG, 'cell');
            testCase.verifyNumElements(ALLEEG, 1);
            EEG = ALLEEG{1};
            testCase.verifyEqual(EEG.data, data);
            testCase.verifyEqual(EEG.nbchan, 4);
            testCase.verifyEqual(EEG.pnts, 50);
            testCase.verifyEqual(EEG.srate, 250);
            testCase.verifyEqual(EEG.trials, 1);
            testCase.verifyEqual(EEG.xmin, 0);
            testCase.verifyEqual(EEG.xmax, 49/250, 'AbsTol', 1e-12);
            testCase.verifySubstring(EEG.comments, fullfile(testCase.Dir, 'rec.bvrh'));
            testCase.verifyEqual({EEG.chanlocs.labels}, {'Ch1', 'Ch2', 'Ch3', 'Ch4'});
            testCase.verifyEqual({EEG.chanlocs.type}, {'EEG', 'EEG', 'EEG', 'EEG'});
        end

        function singleParticipantNaming(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 5));
            EEG = testCase.loadOne();
            testCase.verifyEqual(EEG.subject, 'participant-1');
            testCase.verifyEqual(EEG.etc.participant_id, 'participant-1');
            testCase.verifyEqual(EEG.setname, 'BVRF_participant-1');
            testCase.verifyEqual(EEG.condition, '');
        end

        function taskNameUsedForConditionAndSetname(testCase)
            hdr = bvrftest.baseHeader(2);
            hdr.Task = struct('Name', 'P300');
            testCase.write(hdr, bvrftest.pattern(2, 5));
            EEG = testCase.loadOne();
            testCase.verifyEqual(EEG.condition, 'P300');
            testCase.verifyEqual(EEG.setname, 'P300_participant-1');
        end

        function headerStringValuesKeepSpaces(testCase)
            % Header strings such as Task.Name may contain spaces.
            hdr = bvrftest.baseHeader(2);
            hdr.Task = struct('Name', 'Seeing stuff');
            testCase.write(hdr, bvrftest.pattern(2, 5));
            [ALLEEG, hdrOut] = testCase.loadAll();
            testCase.verifyEqual(hdrOut.Task.Name, 'Seeing stuff');
            testCase.verifyEqual(ALLEEG{1}.condition, 'Seeing stuff');
        end

        function paddedNamesAndIdsStillMatch(testCase)
            % Invisible leading/trailing spaces in header values must not
            % break matching: channel -> electrode, channel -> participant,
            % and header participant -> marker file ParticipantId.
            hdr = bvrftest.baseHeader(2, 'ParticipantIds', {'p1', 'p2'}, ...
                'Coordinates', [1 2 3; 4 5 6], 'CoordSys', 'EEGLAB');
            hdr.Participants{1}.Id = 'p1 ';
            hdr.EEGModality.Channels{1}.ParticipantId = ' p1';
            hdr.EEGModality.Channels{1}.Composition.Plus.Name = 'Ch1 ';
            mk = {'Type', 'Sample', 'ParticipantId', 'Comment'
                  'A',    '1',      'p1',            ''
                  'B',    '2',      'p2',            ''};
            testCase.write(hdr, bvrftest.pattern(2, 10), 'Markers', mk);

            ALLEEG = testCase.loadAll();

            testCase.verifyNumElements(ALLEEG, 2);
            testCase.verifyEqual(ALLEEG{1}.subject, 'p1');
            testCase.verifyEqual(ALLEEG{1}.nbchan, 1);
            testCase.verifyEqual([ALLEEG{1}.chanlocs.X], 1);   % electrode found
            testCase.verifyEqual(string({ALLEEG{1}.event.type}), "A");
            testCase.verifyEqual(string({ALLEEG{2}.event.type}), "B");
        end

        function headerIsStoredInEtc(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 5));
            [ALLEEG, hdr] = testCase.loadAll();
            testCase.verifyEqual(ALLEEG{1}.etc.bvrf_header, hdr);
        end

        function metadataOnlyReturnsEmptyALLEEG(testCase)
            testCase.write(bvrftest.baseHeader(2, 'Srate', 500), []);   % no data file
            [ALLEEG, hdr] = testCase.loadAll('flagMetadata', true);
            testCase.verifyEmpty(ALLEEG);
            testCase.verifyEqual(hdr.EEGModality.DataSpecific.SamplingFrequencyInHertz, 500);
        end

        function missingDataFileErrors(testCase)
            testCase.write(bvrftest.baseHeader(2), []);
            testCase.verifyError(@() testCase.loadAll(), ?MException);
        end

        function missingHeaderFileErrors(testCase)
            testCase.verifyError(@() testCase.loadAll(), ?MException);
        end

        function tooFewArgumentsErrors(testCase)
            testCase.verifyError(@() eeg_loadbvrf(testCase.Dir), ...
                'eeg_loadbvrf:NotEnoughArguments');
        end
    end

    % =================================================================
    %  Scaling and calibration polynomials
    % =================================================================
    methods (Test)
        function resolutionPerBitScaling(testCase)
            data = bvrftest.pattern(3, 10);
            testCase.write(bvrftest.baseHeader(3, 'ResolutionPerBit', 0.5), data);
            EEG = testCase.loadOne();
            testCase.verifyEqual(EEG.data, data * 0.5, 'AbsTol', 1e-12);
        end

        function polynomialAppliedWhenUsePolyTrue(testCase)
            [data, num, den, re] = testCase.writePolyRecording();
            EEG = testCase.loadOne('usePoly', true);
            so = data(2, :) * re;
            expected = (num(1) + num(2) * so) ./ (1 + den(2) * so);
            testCase.verifyEqual(EEG.data(2, :), expected, 'RelTol', 1e-12);
            testCase.verifyEqual(EEG.data([1 3], :), data([1 3], :) * re, 'AbsTol', 1e-12);
        end

        function polynomialIgnoredWhenUsePolyFalse(testCase)
            [data, ~, ~, re] = testCase.writePolyRecording();
            EEG = testCase.loadOne('usePoly', false);
            testCase.verifyEqual(EEG.data, data * re, 'AbsTol', 1e-12);
        end

        function identityPolynomialEqualsResolutionScaling(testCase)
            data = bvrftest.pattern(2, 10);
            hdr = bvrftest.baseHeader(2, 'ResolutionPerBit', 0.25);
            hdr.EEGModality.Channels{1}.Coefficients = struct('Num', [0 1], 'Denom', 1);
            testCase.write(hdr, data);
            EEG = testCase.loadOne();
            testCase.verifyEqual(EEG.data, data * 0.25, 'AbsTol', 1e-12);
        end
    end

    % =================================================================
    %  Sample intervals (1-based, inclusive) and marker alignment
    % =================================================================
    methods (Test)
        function sampleIntervalSelectsSegment(testCase)
            data = bvrftest.pattern(3, 40);
            testCase.write(bvrftest.baseHeader(3), data);

            EEG = testCase.loadOne('sampleInterval', [11 30]);

            testCase.verifyEqual(EEG.data, data(:, 11:30));
            testCase.verifyEqual(EEG.pnts, 20);
            testCase.verifyEqual(EEG.xmin, 0);
            testCase.verifyEqual(EEG.etc.bvrf.sampleInterval, [11 30]);
            testCase.verifyEqual(EEG.etc.bvrf.fileSampleOffset, 10);
        end

        function fullReadRecordsWholeInterval(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 25));
            EEG = testCase.loadOne();
            testCase.verifyEqual(EEG.etc.bvrf.sampleInterval, [1 25]);
            testCase.verifyEqual(EEG.etc.bvrf.fileSampleOffset, 0);
        end

        function sampleIntervalPastEndIsClamped(testCase)
            data = bvrftest.pattern(2, 20);
            testCase.write(bvrftest.baseHeader(2), data);
            lastwarn('');
            EEG = testCase.loadOne('sampleInterval', [15 100]);
            testCase.verifyNotEmpty(lastwarn, 'Expected a warning about clamping.');
            testCase.verifyEqual(EEG.data, data(:, 15:20));
            testCase.verifyEqual(EEG.etc.bvrf.sampleInterval, [15 20]);
        end

        function invalidSampleIntervalsError(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20));
            bad = {[0 5], [6 5], [1.5 4], [1 2 3], 5, [21 25]};
            for k = 1:numel(bad)
                testCase.verifyError(@() testCase.loadAll('sampleInterval', bad{k}), ...
                    ?MException, sprintf('sampleInterval %s should error.', mat2str(bad{k})));
            end
        end

        function markerLatenciesFullRead(testCase)
            mk = {'Type', 'Sample'
                  'A',    '0'
                  'B',    '9'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual([ev.latency], [1 10]);    % 0-based file sample + 1
            testCase.verifyEqual([ev.bv_sample], [0 9]);
        end

        function markerLatenciesFollowSegment(testCase)
            mk = {'Type', 'Sample'
                  'before', '5'     % file sample 6  -> outside [11 30]
                  'first',  '10'    % file sample 11 -> latency 1
                  'last',   '29'    % file sample 30 -> latency 20
                  'after',  '30'};  % file sample 31 -> outside
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 40), 'Markers', mk);

            EEG = testCase.loadOne('sampleInterval', [11 30]);
            ev = EEG.event;

            testCase.verifyEqual(string({ev.type}), ["first", "last"]);
            testCase.verifyEqual([ev.latency], [1 20]);
            testCase.verifyEqual([ev.bv_sample], [10 29]);
            testCase.verifyEqual([ev.latency], ...
                [ev.bv_sample] - EEG.etc.bvrf.fileSampleOffset + 1);
        end

        function markerLatencyFromSampleIndex(testCase)
            mk = {'Type', 'SampleIndex'
                  'A',    '4'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual(ev.latency, 5);
        end

        function markerLatencyFromTime(testCase)
            mk = {'Type', 'Time'
                  'A',    '0.25'};
            testCase.write(bvrftest.baseHeader(2, 'Srate', 100), bvrftest.pattern(2, 50), ...
                'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual(ev.latency, 26);   % round(0.25*100) = 25 (0-based) -> 26
            testCase.verifyEqual(ev.bv_sample, 25);
        end

        function markerWithoutPositionIsSkipped(testCase)
            mk = {'Type', 'Sample'
                  'A',    ''
                  'B',    '3'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual(string({ev.type}), "B");
        end
    end

    % =================================================================
    %  Marker -> event fields
    % =================================================================
    methods (Test)
        function eventTypeFromTypeCodeValue(testCase)
            mk = {'Type',     'Code', 'Value', 'Sample', 'Comment'
                  'Comment',  '',     '',      '1',      'hello'
                  'Stimulus', 'S1',   '',      '2',      ''
                  'Stimulus', '',     '7',     '3',      ''
                  'Stimulus', 'PS',   '50',    '4',      ''};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();

            testCase.verifyEqual(string({ev.type}), ...
                ["Comment", "Stimulus/S1", "Stimulus/7", "Stimulus/PS50"]);
            testCase.verifyEqual(string(ev(1).comment), "hello");
            testCase.verifyEqual(string({ev.bv_type}), ["Comment", "Stimulus", "Stimulus", "Stimulus"]);
        end

        function eventTypeDefaultsToMarker(testCase)
            mk = {'Sample'
                  '2'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual(string(ev.type), "Marker");
        end

        function bvSpecificEventFields(testCase)
            mk = {'Type',     'Code', 'Value', 'Sample', 'StartEndId', 'Channel'
                  'Stimulus', 'S',    '1',     '2',      'abc',        'Ch2'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            ev = testCase.loadEvents();
            testCase.verifyEqual(string(ev.bv_type), "Stimulus");
            testCase.verifyEqual(string(ev.bv_code), "S");
            testCase.verifyEqual(string(ev.bv_value), "1");
            testCase.verifyEqual(string(ev.bv_StartEndId), "abc");
            testCase.verifyEqual(string(ev.bv_channel), "Ch2");
        end

        function markersNotImportedWhenFlagFalse(testCase)
            mk = {'Type', 'Sample'; 'A', '1'};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20), 'Markers', mk);
            EEG = testCase.loadOne('flagImportMarkers', false);
            testCase.verifyEmpty(EEG.event);
        end

        function missingMarkerFileWarnsAndYieldsNoEvents(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 20));
            lastwarn('');
            EEG = testCase.loadOne();
            testCase.verifyNotEmpty(lastwarn);
            testCase.verifyEmpty(EEG.event);
        end
    end

    % =================================================================
    %  Participants and channel selection
    % =================================================================
    methods (Test)
        function oneDatasetPerParticipant(testCase)
            ids  = {'p1', 'p2', 'p1', 'p2'};
            data = bvrftest.pattern(4, 10);
            testCase.write(bvrftest.baseHeader(4, 'ParticipantIds', ids), data);

            ALLEEG = testCase.loadAll();

            testCase.verifyNumElements(ALLEEG, 2);
            testCase.verifyEqual(ALLEEG{1}.subject, 'p1');
            testCase.verifyEqual(ALLEEG{2}.subject, 'p2');
            testCase.verifyEqual(ALLEEG{1}.setname, 'BVRF_p1');
            testCase.verifyEqual(ALLEEG{1}.data, data([1 3], :));
            testCase.verifyEqual(ALLEEG{2}.data, data([2 4], :));
            testCase.verifyEqual({ALLEEG{2}.chanlocs.labels}, {'Ch2', 'Ch4'});
        end

        function commonSensorsCopiedToEveryParticipant(testCase)
            ids  = {'p1', 'p2', '', 'p1', 'p2'};   % Ch3 has no ParticipantId
            data = bvrftest.pattern(5, 10);
            testCase.write(bvrftest.baseHeader(5, 'ParticipantIds', ids), data);

            ALLEEG = testCase.loadAll();

            testCase.verifyEqual({ALLEEG{1}.chanlocs.labels}, {'Ch1', 'Ch3', 'Ch4'});
            testCase.verifyEqual({ALLEEG{2}.chanlocs.labels}, {'Ch2', 'Ch3', 'Ch5'});
            testCase.verifyEqual(ALLEEG{1}.data, data([1 3 4], :));
            testCase.verifyEqual(ALLEEG{2}.data, data([2 3 5], :));
        end

        function participantsWithIdenticalFields(testCase)
            % jsondecode returns a struct array (not a cell array) when all
            % Participants entries have the same fields.
            hdr = bvrftest.baseHeader(2, 'ParticipantIds', {'p1', 'p2'});
            hdr.Participants = {struct('Id', 'p1'), struct('Id', 'p2')};
            data = bvrftest.pattern(2, 10);
            testCase.write(hdr, data);

            ALLEEG = testCase.loadAll();

            testCase.verifyNumElements(ALLEEG, 2);
            testCase.verifyEqual(ALLEEG{2}.data, data(2, :));
        end

        function selectParticipantById(testCase)
            ids  = {'p1', 'p2', 'p1', 'p2'};
            data = bvrftest.pattern(4, 10);
            testCase.write(bvrftest.baseHeader(4, 'ParticipantIds', ids), data);

            ALLEEG = testCase.loadAll('participantId', 'p2');

            testCase.verifyNumElements(ALLEEG, 1);
            testCase.verifyEqual(ALLEEG{1}.subject, 'p2');
            testCase.verifyEqual(ALLEEG{1}.data, data([2 4], :));
        end

        function unknownParticipantIdErrors(testCase)
            testCase.write(bvrftest.baseHeader(2, 'ParticipantIds', {'p1', 'p2'}), ...
                bvrftest.pattern(2, 10));
            testCase.verifyError(@() testCase.loadAll('participantId', 'zzz'), ...
                'eeg_loadbvrf:ParticipantNotFound');
        end

        function markersAssignedToParticipants(testCase)
            ids = {'p1', 'p2'};
            mk = {'Type', 'Sample', 'ParticipantId', 'Comment'
                  'A',    '1',      'p1',            ''
                  'B',    '2',      'p2',            ''
                  'C',    '3',      '',              ''
                  'D',    '4',      'p2',            'all participants'};
            testCase.write(bvrftest.baseHeader(2, 'ParticipantIds', ids), ...
                bvrftest.pattern(2, 10), 'Markers', mk);

            ALLEEG = testCase.loadAll();

            testCase.verifyEqual(string({ALLEEG{1}.event.type}), ["A", "C", "D"]);
            testCase.verifyEqual(string({ALLEEG{2}.event.type}), ["B", "C", "D"]);
        end

        function channelIndxSelectsAndOrders(testCase)
            data = bvrftest.pattern(4, 10);
            testCase.write(bvrftest.baseHeader(4), data);
            EEG = testCase.loadOne('channelIndx', [3 1]);
            testCase.verifyEqual(EEG.nbchan, 2);
            testCase.verifyEqual({EEG.chanlocs.labels}, {'Ch3', 'Ch1'});
            testCase.verifyEqual(EEG.data, data([3 1], :));
        end

        function channelIndxOutOfRangeErrors(testCase)
            testCase.write(bvrftest.baseHeader(4), bvrftest.pattern(4, 10));
            testCase.verifyError(@() testCase.loadAll('channelIndx', 5), ?MException);
        end
    end

    % =================================================================
    %  Reference (EEG.ref)
    % =================================================================
    methods (Test)
        function refUnknownWhenNoMinus(testCase)
            testCase.verifyEqual(testCase.refFor({[], [], []}), 'unknown');
        end

        function refUnknownWhenMixed(testCase)
            testCase.verifyEqual(testCase.refFor({'REF', [], 'REF'}), 'unknown');
        end

        function refUnknownWhenDifferent(testCase)
            testCase.verifyEqual(testCase.refFor({'REF', 'Cz', 'REF'}), 'unknown');
        end

        function refNamedWhenAllShareMinus(testCase)
            testCase.verifyEqual(testCase.refFor({'REF', 'REF', 'REF'}), 'REF');
        end

        function refCommonWhenSharedButUnnamed(testCase)
            testCase.verifyEqual(testCase.refFor({'', '', ''}), 'common');
        end

        function referencesSectionStoredInEtc(testCase)
            hdr = bvrftest.baseHeader(2);
            hdr.EEGModality.References = {struct('Name', 'REF')};
            testCase.write(hdr, bvrftest.pattern(2, 5));
            [ALLEEG, hdrOut] = testCase.loadAll();
            testCase.verifyEqual(ALLEEG{1}.etc.bvrf.references, hdrOut.EEGModality.References);
        end
    end

    % =================================================================
    %  Coordinates (EEG.chanlocs X/Y/Z)
    % =================================================================
    methods (Test)
        function rasSystemsConvertedToEeglab(testCase)
            % RAS (+X right, +Y anterior, +Z up) -> ALS: X = Y_file, Y = -X_file
            for sys = {'Easycap', 'CapTrak'}
                xyz = testCase.coordsFor(sys{1}, [1 2 3; -4 5 6]);
                testCase.verifyEqual(xyz, [2 -1 3; 5 4 6], 'AbsTol', 1e-12, sys{1});
            end
        end

        function eeglabSystemUnchanged(testCase)
            xyz = testCase.coordsFor('EEGLAB', [1 2 3; -4 5 6]);
            testCase.verifyEqual(xyz, [1 2 3; -4 5 6]);
        end

        function unspecifiedSystemUnchanged(testCase)
            xyz = testCase.verifyWarningFree(@() testCase.coordsFor('', [1 2 3; -4 5 6]));
            testCase.verifyEqual(xyz, [1 2 3; -4 5 6]);
        end

        function unknownSystemWarnsAndKeepsCoordinates(testCase)
            xyz = testCase.verifyWarning(@() testCase.coordsFor('Foo', [1 2 3; -4 5 6]), ...
                'eeg_loadbvrf:unknownCoordSys');
            testCase.verifyEqual(xyz, [1 2 3; -4 5 6]);
        end

        function channelsWithoutElectrodeHaveEmptyCoordinates(testCase)
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 5));
            EEG = testCase.loadOne();
            testCase.verifyEmpty(EEG.chanlocs(1).X);
            testCase.verifyEmpty(EEG.chanlocs(1).Y);
            testCase.verifyEmpty(EEG.chanlocs(1).Z);
        end
    end

    % =================================================================
    %  Impedances
    % =================================================================
    methods (Test)
        function impedancesImportedWhenRequested(testCase)
            imp = {sprintf('Electrode\tCh1\tCh2')
                   'Impedance Measurements [kOhm]'
                   sprintf('2025-11-20T09:44:07\t38\t40')};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 5), 'Impedances', imp);

            EEG = testCase.loadOne('flagImportImpedances', true);

            testCase.verifyTrue(isfield(EEG.etc, 'impedances'));
            testCase.verifyEqual(string(EEG.etc.impedances.Ch1{1}), "38");
            testCase.verifyEqual(string(EEG.etc.impedances.Ch2{1}), "40");
        end

        function impedancesNotImportedByDefault(testCase)
            imp = {sprintf('Electrode\tCh1\tCh2'), sprintf('t\t38\t40')};
            testCase.write(bvrftest.baseHeader(2), bvrftest.pattern(2, 5), 'Impedances', imp);
            EEG = testCase.loadOne();
            testCase.verifyFalse(isfield(EEG.etc, 'impedances'));
        end
    end

    % =================================================================
    %  Helpers
    % =================================================================
    methods
        function [data, num, den, re] = writePolyRecording(testCase)
            % 3 channels; channel 2 carries a rational calibration polynomial.
            data = bvrftest.pattern(3, 10);
            num = [0.5 2];
            den = [1 -0.0004];
            re  = 0.1;
            hdr = bvrftest.baseHeader(3, 'ResolutionPerBit', re);
            hdr.EEGModality.Channels{2}.Coefficients = struct('Num', num, 'Denom', den);
            testCase.write(hdr, data);
        end

        function ref = refFor(testCase, minusNames)
            % minusNames{k}: [] = no Minus, otherwise the Minus name ('' allowed).
            n = numel(minusNames);
            hdr = bvrftest.baseHeader(n);
            for k = 1:n
                if ~isnumeric(minusNames{k})
                    hdr.EEGModality.Channels{k}.Composition.Minus = ...
                        struct('Name', minusNames{k}, 'Section', 'References');
                end
            end
            testCase.write(hdr, bvrftest.pattern(n, 5));
            EEG = testCase.loadOne();
            ref = EEG.ref;
        end

        function xyz = coordsFor(testCase, coordSys, coords)
            n = size(coords, 1);
            testCase.write(bvrftest.baseHeader(n, 'Coordinates', coords, 'CoordSys', coordSys), ...
                bvrftest.pattern(n, 5));
            EEG = testCase.loadOne('flagImportMarkers', false);   % no marker-file warning
            loc = EEG.chanlocs;
            xyz = [[loc.X]', [loc.Y]', [loc.Z]'];
        end
    end
end
