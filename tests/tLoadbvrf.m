classdef tLoadbvrf < matlab.unittest.TestCase
    % Unit tests for the low-level reader loadbvrf.m, using synthetic files.

    properties
        Dir   % temporary folder for the current test
    end

    properties (TestParameter)
        precision = {'Int16', 'Int32', 'Single', 'Double'};
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

    methods (Test)
        function fullReadAllPrecisions(testCase, precision)
            data = bvrftest.pattern(3, 20);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', ...
                bvrftest.baseHeader(3, 'Precision', precision), data);

            [~, ids, out] = loadbvrf(f);

            testCase.verifyEqual(ids, {'participant-1'});
            testCase.verifyEqual(double(out{1}), data);
        end

        function resolutionPerBitIsApplied(testCase)
            data = bvrftest.pattern(2, 10);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', ...
                bvrftest.baseHeader(2, 'ResolutionPerBit', 0.1), data);
            [~, ~, out] = loadbvrf(f);
            testCase.verifyEqual(out{1}, data * 0.1, 'AbsTol', 1e-9);
        end

        function trailingPartialFrameIsDropped(testCase)
            data = bvrftest.pattern(3, 10);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), data, ...
                'TrailingValues', [7 7]);
            [~, ~, out] = loadbvrf(f);
            testCase.verifyEqual(out{1}, data);
        end

        function sampleRangeWholeFile(testCase)
            data = bvrftest.pattern(3, 30);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), data);
            [~, ~, out] = loadbvrf(f, [1 30]);
            testCase.verifyEqual(out{1}, data);
        end

        function sampleRangeIsOneBasedInclusive(testCase)
            data = bvrftest.pattern(3, 30);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), data);

            [~, ~, out] = loadbvrf(f, [5 9]);
            testCase.verifyEqual(out{1}, data(:, 5:9));

            [~, ~, out] = loadbvrf(f, [12 12]);
            testCase.verifyEqual(out{1}, data(:, 12));

            [~, ~, out] = loadbvrf(f, [30 30]);
            testCase.verifyEqual(out{1}, data(:, 30));
        end

        function sampleRangeErrors(testCase)
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), ...
                bvrftest.pattern(3, 30));
            testCase.verifyError(@() loadbvrf(f, [0 5]),  ?MException);   % 0 is not a valid index
            testCase.verifyError(@() loadbvrf(f, [6 5]),  ?MException);   % last < first
            testCase.verifyError(@() loadbvrf(f, [31 40]), ?MException);  % first beyond EOF
            testCase.verifyError(@() loadbvrf(f, 5),      ?MException);   % not [first last]
        end

        function sampleRangePastEndIsClampedWithWarning(testCase)
            data = bvrftest.pattern(3, 30);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), data);
            lastwarn('');
            [~, ~, out] = loadbvrf(f, [25 100]);
            testCase.verifyNotEmpty(lastwarn, 'Expected a warning about clamping.');
            testCase.verifyEqual(out{1}, data(:, 25:30));
        end

        function metadataOnlyReturnsHeader(testCase)
            hdrIn = bvrftest.baseHeader(3, 'Srate', 512);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', hdrIn, []);   % no data file
            hdr = loadbvrf(f, [], true);
            testCase.verifyEqual(hdr.EEGModality.DataSpecific.SamplingFrequencyInHertz, 512);
            testCase.verifyEqual(hdr.BVRF.Version, '1.0.0');
        end

        function missingHeaderFileErrors(testCase)
            testCase.verifyError(@() loadbvrf(fullfile(testCase.Dir, 'nope.bvrh')), ?MException);
        end

        function missingDataFileErrors(testCase)
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', bvrftest.baseHeader(3), []);
            testCase.verifyError(@() loadbvrf(f), ?MException);
        end

        function missingRequiredHeaderFieldsError(testCase)
            base = bvrftest.baseHeader(2);
            data = bvrftest.pattern(2, 5);
            mutations = {
                @(h) rmfield(h, 'BVRF')
                @(h) rmfield(h, 'BVRFHeaderFile')
                @(h) rmfield(h, 'EEGModality')
                @(h) removeModalityField(h, 'BVRFFiles')      % NumericDataType
                @(h) removeModalityField(h, 'DataSpecific')   % sampling rate
                @(h) removeModalityField(h, 'Channels')
                };
            for k = 1:numel(mutations)
                f = bvrftest.writeBvrf(testCase.Dir, sprintf('rec%d', k), base, data);
                writeHeader(f, mutations{k}(base));
                testCase.verifyError(@() loadbvrf(f), ?MException, ...
                    sprintf('Header mutation %d should raise an error.', k));
            end
        end

        function splitsChannelsByParticipant(testCase)
            ids  = {'p1', 'p2', 'p1', 'p2'};
            data = bvrftest.pattern(4, 8);
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', ...
                bvrftest.baseHeader(4, 'ParticipantIds', ids), data);

            [~, pid, out, chans] = loadbvrf(f);

            testCase.verifyEqual(pid(:)', {'p1', 'p2'});
            testCase.verifyEqual(out{1}, data([1 3], :));
            testCase.verifyEqual(out{2}, data([2 4], :));
            testCase.verifyEqual(cellfun(@(c) c.Name, chans{2}, 'UniformOutput', false), ...
                {'Ch2'; 'Ch4'});
        end

        function markersAreAssignedToParticipants(testCase)
            ids = {'p1', 'p2'};
            mk = {'Type', 'Sample', 'ParticipantId', 'Comment'
                  'A',    '1',      'p1',            ''
                  'B',    '2',      'p2',            ''
                  'C',    '3',      '',              ''
                  'D',    '4',      'p2',            'all participants'};
            f = bvrftest.writeBvrf(testCase.Dir, 'rec', ...
                bvrftest.baseHeader(2, 'ParticipantIds', ids), bvrftest.pattern(2, 10), ...
                'Markers', mk);

            [~, ~, ~, ~, markers] = loadbvrf(f);

            types = @(m) cellstr([m.Type]);
            testCase.verifyEqual(types(markers{1}), {'A', 'C', 'D'});
            testCase.verifyEqual(types(markers{2}), {'B', 'C', 'D'});
        end
    end
end

% ---------------------------------------------------------------------
function h = removeModalityField(h, field)
h.EEGModality = rmfield(h.EEGModality, field);
end

function writeHeader(hdrFile, hdr)
fid = fopen(hdrFile, 'w', 'n', 'UTF-8');
c = onCleanup(@() fclose(fid));
fprintf(fid, '%s', jsonencode(hdr));
end
