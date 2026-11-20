classdef tEvalRationalPoly < matlab.unittest.TestCase
    % Unit tests for evalRationalPolyAscending.m

    methods (TestClassSetup)
        function setupPath(testCase)
            bvrftest.addPaths(testCase);
        end
    end

    methods (Test)
        function identityPolynomialReturnsScaledInput(testCase)
            nv = [-3 0 1 250];
            testCase.verifyEqual(evalRationalPolyAscending(nv, [0 1], 1, 1), nv);
        end

        function resolutionIsAppliedBeforePolynomial(testCase)
            nv = [1 2 3];
            % Num = [0 1] -> MQ = NV * RE
            testCase.verifyEqual(evalRationalPolyAscending(nv, [0 1], 1, 0.5), nv * 0.5);
        end

        function numeratorOnly(testCase)
            nv = [0 1 2 10];
            so = nv * 0.5;
            expected = 2 + 3*so + 4*so.^2;
            testCase.verifyEqual(evalRationalPolyAscending(nv, [2 3 4], 1, 0.5), ...
                expected, 'AbsTol', 1e-12);
        end

        function numeratorAndDenominator(testCase)
            nv = [0 1 2 10];
            so = nv * 2;
            expected = (1 + 2*so) ./ (1 + 0.5*so + 0.25*so.^2);
            testCase.verifyEqual(evalRationalPolyAscending(nv, [1 2], [1 0.5 0.25], 2), ...
                expected, 'AbsTol', 1e-12);
        end

        function emptyDenominatorDefaultsToOne(testCase)
            nv = [1 5 9];
            testCase.verifyEqual(evalRationalPolyAscending(nv, [1 2], [], 1), ...
                evalRationalPolyAscending(nv, [1 2], 1, 1));
        end

        function coefficientOrientationDoesNotMatter(testCase)
            nv = [1 5 9];
            testCase.verifyEqual(evalRationalPolyAscending(nv, [1; 2], [1; 0.5], 1), ...
                evalRationalPolyAscending(nv, [1 2], [1 0.5], 1));
        end

        function outputKeepsInputShapeAndIsDouble(testCase)
            nv = int16([1 2 3; 4 5 6]);
            y = evalRationalPolyAscending(nv, [0 1], 1, 1);
            testCase.verifyClass(y, 'double');
            testCase.verifySize(y, [2 3]);
            testCase.verifyEqual(y, double(nv));
        end
    end
end
