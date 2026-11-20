classdef tHelpers < matlab.unittest.TestCase
    % Unit tests for safe_get.m and normalizeObjectArray.m

    methods (TestClassSetup)
        function setupPath(testCase)
            bvrftest.addPaths(testCase);
        end
    end

    methods (Test)
        % ---------------- safe_get ----------------
        function safeGetReturnsExistingValue(testCase)
            s = struct('Name', 'Cz');
            testCase.verifyEqual(safe_get(s, 'Name', 'x'), 'Cz');
        end

        function safeGetReturnsDefaultForMissingField(testCase)
            testCase.verifyEqual(safe_get(struct('a', 1), 'b', 42), 42);
        end

        function safeGetReturnsDefaultForEmptyField(testCase)
            testCase.verifyEqual(safe_get(struct('a', []), 'a', 'def'), 'def');
        end

        function safeGetReturnsDefaultForNonStruct(testCase)
            testCase.verifyEqual(safe_get([], 'a', 7), 7);
            testCase.verifyEqual(safe_get('text', 'a', 7), 7);
        end

        % ------------- normalizeObjectArray -------------
        function normalizeStructArrayToCell(testCase)
            s = struct('Name', {'a', 'b', 'c'});
            [objs, errs] = normalizeObjectArray(s, 'X');
            testCase.verifyEmpty(errs);
            testCase.verifyClass(objs, 'cell');
            testCase.verifyNumElements(objs, 3);
            testCase.verifyEqual(objs{2}.Name, 'b');
        end

        function normalizeCellPassesThrough(testCase)
            c = {struct('Name', 'a'), struct('Name', 'b', 'Extra', 1)};
            [objs, errs] = normalizeObjectArray(c, 'X');
            testCase.verifyEmpty(errs);
            testCase.verifyEqual(objs, c);
        end

        function normalizeReportsEmptyInput(testCase)
            [~, errs] = normalizeObjectArray({}, 'X');
            testCase.verifyNotEmpty(errs);
            [~, errs] = normalizeObjectArray(struct([]), 'X');
            testCase.verifyNotEmpty(errs);
        end

        function normalizeReportsNonStructElements(testCase)
            [~, errs] = normalizeObjectArray({struct('a', 1), 5}, 'X');
            testCase.verifyNumElements(errs, 1);
        end

        function normalizeReportsWrongType(testCase)
            [objs, errs] = normalizeObjectArray(42, 'X');
            testCase.verifyEmpty(objs);
            testCase.verifyNotEmpty(errs);
        end

        % ------------- trimHeaderStrings -------------
        function trimRemovesOnlyOuterWhitespace(testCase)
            testCase.verifyEqual(trimHeaderStrings(sprintf(' \tSeeing stuff  ')), 'Seeing stuff');
            testCase.verifyEqual(trimHeaderStrings(" AUX 1 "), "AUX 1");
        end

        function trimRecursesIntoNestedContainers(testCase)
            hdr.Task = struct('Name', ' P300 ');
            hdr.Channels = {struct('Name', 'Fp1 ', 'Composition', ...
                struct('Plus', struct('Name', ' Fp1')))};
            hdr.Electrodes = struct('Name', {'Cz ', ' Pz'});   % struct array
            out = trimHeaderStrings(hdr);
            testCase.verifyEqual(out.Task.Name, 'P300');
            testCase.verifyEqual(out.Channels{1}.Name, 'Fp1');
            testCase.verifyEqual(out.Channels{1}.Composition.Plus.Name, 'Fp1');
            testCase.verifyEqual({out.Electrodes.Name}, {'Cz', 'Pz'});
        end

        function trimLeavesNonTextUnchanged(testCase)
            s = struct('Srate', 500, 'Coords', [1 2 3], 'Flag', true, 'Empty', []);
            testCase.verifyEqual(trimHeaderStrings(s), s);
        end
    end
end
