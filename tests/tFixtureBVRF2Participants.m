classdef tFixtureBVRF2Participants < matlab.unittest.TestCase
    % Regression tests on the small committed recording in tests/fixtures
    % (2 participants, 6 Int16 channels, 4 Hz, one common-to-all set of markers).

    properties
        ALLEEG
        Hdr
    end

    methods (TestClassSetup)
        function loadFixture(testCase)
            bvrftest.addPaths(testCase);
            folder = fullfile(fileparts(mfilename('fullpath')), 'fixtures');
            [testCase.Hdr, testCase.ALLEEG] = eeg_loadbvrf(folder, 'BVRF2Participants.bvrh');
        end
    end

    methods (Test)
        function twoParticipantsInHeaderOrder(testCase)
            testCase.verifyNumElements(testCase.ALLEEG, 2);
            testCase.verifyEqual(testCase.ALLEEG{1}.subject, 'part-01');
            testCase.verifyEqual(testCase.ALLEEG{2}.subject, 'part-02');
        end

        function channelsGroupedPerParticipant(testCase)
            testCase.verifyEqual({testCase.ALLEEG{1}.chanlocs.labels}, {'Cz', 'Fp1', 'GSR'});
            testCase.verifyEqual({testCase.ALLEEG{2}.chanlocs.labels}, {'Fp1', 'Cz', 'GSR'});
            testCase.verifyEqual({testCase.ALLEEG{1}.chanlocs.type}, {'EEG', 'EEG', 'GSR'});
        end

        function sampleCountFromFileSize(testCase)
            % 280 bytes / (6 channels * 2 bytes) = 23 full samples.
            for p = 1:2
                testCase.verifyEqual(testCase.ALLEEG{p}.pnts, 23);
                testCase.verifyEqual(testCase.ALLEEG{p}.srate, 4);
            end
        end

        function referenceIsUnknownBecauseGsrHasNoMinus(testCase)
            % part-02 EEG channels share Minus = REF but the GSR channel has
            % no Minus, so the README rules give 'unknown' for both.
            testCase.verifyEqual(testCase.ALLEEG{1}.ref, 'unknown');
            testCase.verifyEqual(testCase.ALLEEG{2}.ref, 'unknown');
        end

        function markersAssignedPerParticipant(testCase)
            ev1 = testCase.ALLEEG{1}.event;
            ev2 = testCase.ALLEEG{2}.event;
            testCase.verifyEqual([ev1.bv_sample], [0 5 7 9 9]);
            testCase.verifyEqual([ev2.bv_sample], [0 5 8 9 9]);
            testCase.verifyEqual([ev1.latency], [ev1.bv_sample] + 1);
        end
    end
end
