function addPaths(testCase)
% bvrftest.addPaths - Put the repository root on the path for one test class.
%
% Call from a TestClassSetup method. The path is restored when the class
% finishes (PathFixture).
testsDir = fileparts(fileparts(mfilename('fullpath')));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(testsDir)));
end
