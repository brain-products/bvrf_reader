classdef tPopLoadbvrf < matlab.unittest.TestCase
    % Tests for the scripted (no GUI) path of pop_loadbvrf.m.

    properties
        Dir
        Data
    end

    methods (TestClassSetup)
        function setupPath(testCase)
            bvrftest.addPaths(testCase);
        end
    end

    methods (TestMethodSetup)
        function writeRecording(testCase)
            f = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Dir  = f.Folder;
            testCase.Data = bvrftest.pattern(4, 30);
            mk = {'Type', 'Sample', 'ParticipantId', 'Comment'
                  'A',    '2',      'p1',            ''
                  'B',    '12',     'p2',            ''};
            bvrftest.writeBvrf(testCase.Dir, 'rec', ...
                bvrftest.baseHeader(4, 'ParticipantIds', {'p1', 'p2', 'p1', 'p2'}), ...
                testCase.Data, 'Markers', mk);
        end
    end

    methods (Test)
        function scriptedCallMatchesLowLevelLoader(testCase)
            [ALLEEG, com] = pop_loadbvrf(testCase.Dir, 'rec.bvrh');
            [~, ref] = eeg_loadbvrf(testCase.Dir, 'rec.bvrh');

            testCase.verifyNumElements(ALLEEG, 2);
            for p = 1:2
                testCase.verifyEqual(ALLEEG{p}.data, ref{p}.data);
                testCase.verifyEqual(ALLEEG{p}.subject, ref{p}.subject);
            end
            testCase.verifyTrue(startsWith(com, 'ALLEEG = pop_loadbvrf('));
        end

        function optionsAreForwarded(testCase)
            ALLEEG = pop_loadbvrf(testCase.Dir, 'rec.bvrh', ...
                'participantId', 'p2', 'sampleInterval', [11 20], 'channelIndx', 2);

            testCase.verifyNumElements(ALLEEG, 1);
            EEG = ALLEEG{1};
            testCase.verifyEqual(EEG.subject, 'p2');
            testCase.verifyEqual(EEG.data, testCase.Data(4, 11:20));
            testCase.verifyEqual([EEG.event.latency], 12 + 1 - 10);
        end

        function historyCommandReproducesImport(testCase)
            % The 'com' string is stored in EEGLAB's history; evaluating it
            % must reproduce the same import.
            [ALLEEG1, com] = pop_loadbvrf(testCase.Dir, 'rec.bvrh', ...
                'participantId', 'p2', 'sampleInterval', [11 20]);

            ALLEEG = []; %#ok<NASGU>
            eval(com);

            testCase.verifyNumElements(ALLEEG, numel(ALLEEG1));
            testCase.verifyEqual(ALLEEG{1}.data, ALLEEG1{1}.data);
            testCase.verifyEqual(ALLEEG{1}.subject, 'p2');
        end
    end
end
