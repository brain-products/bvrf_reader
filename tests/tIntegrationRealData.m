classdef tIntegrationRealData < matlab.unittest.TestCase
    % Integration tests on real BVRF recordings.
    %
    % The recordings are too large to commit. The tests look for *.bvrh files
    % in the folder named by the BVRF_TEST_DATA environment variable, or in
    % <repo>/Data if that variable is not set. When no recordings are found,
    % the tests are reported as Incomplete (skipped), not as failures.

    properties (TestParameter)
        hdrFile = tIntegrationRealData.findHeaders();
    end

    methods (Static)
        function files = findHeaders()
            folder = getenv('BVRF_TEST_DATA');
            if isempty(folder)
                folder = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'Data');
            end
            d = dir(fullfile(folder, '*.bvrh'));
            if isempty(d)
                files = struct('noData', '');
            else
                names = matlab.lang.makeValidName(erase({d.name}, '.bvrh'));
                files = cell2struct(fullfile({d.folder}, {d.name}), names, 2);
            end
        end
    end

    methods (TestClassSetup)
        function setupPath(testCase)
            bvrftest.addPaths(testCase);
        end
    end

    methods (Test, TestTags = {'Integration'})
        function fullImport(testCase, hdrFile)
            testCase.assumeNotEmpty(hdrFile, 'No real BVRF recordings found.');
            [folder, name, ext] = fileparts(hdrFile);

            [hdr, ALLEEG] = eeg_loadbvrf(folder, [name ext]);

            nPart = 1;
            if isfield(hdr, 'Participants'), nPart = numel(hdr.Participants); end
            testCase.verifyNumElements(ALLEEG, nPart);

            nChanHdr = numel(hdr.EEGModality.Channels);
            totalChans = sum(cellfun(@(E) E.nbchan, ALLEEG));
            testCase.verifyGreaterThanOrEqual(totalChans, nChanHdr);

            for p = 1:numel(ALLEEG)
                EEG = ALLEEG{p};
                testCase.verifyEqual(size(EEG.data), [EEG.nbchan EEG.pnts]);
                testCase.verifyTrue(all(isfinite(EEG.data(:))), 'Data contains NaN/Inf.');
                testCase.verifyNotEmpty(EEG.event, 'Expected markers in a real recording.');
                testCase.verifyTrue(all([EEG.event.latency] >= 1 & [EEG.event.latency] <= EEG.pnts));
            end
        end

        function segmentImportMatchesFullImport(testCase, hdrFile)
            testCase.assumeNotEmpty(hdrFile, 'No real BVRF recordings found.');
            [folder, name, ext] = fileparts(hdrFile);

            [~, full] = eeg_loadbvrf(folder, [name ext], 'flagImportMarkers', false);
            % A segment from the second quarter of the recording (at most 1000 samples).
            n = full{1}.pnts;
            first = floor(n/4) + 1;
            last  = min(first + 999, floor(n/2));
            [~, seg]  = eeg_loadbvrf(folder, [name ext], 'flagImportMarkers', false, ...
                'sampleInterval', [first last]);

            testCase.verifyEqual(seg{1}.pnts, last - first + 1);
            testCase.verifyEqual(seg{1}.data, full{1}.data(:, first:last));
        end
    end
end
