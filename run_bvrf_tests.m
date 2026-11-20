function results = run_bvrf_tests(varargin)
% run_bvrf_tests() - Run the bvrf_reader unit test suite.
%
% Usage:
%   >> results = run_bvrf_tests;                  % all tests
%   >> results = run_bvrf_tests('Integration', false); % skip real-data tests
%   >> results = run_bvrf_tests('CI', true);      % CI mode (see below)
%
% Optional 'key', value pairs:
%   'Integration' - true/false (default: true). Run the tests tagged
%                   'Integration', which use real recordings from Data/ (or
%                   the folder in the BVRF_TEST_DATA environment variable).
%                   They are skipped automatically when no recordings exist.
%   'CI'          - true/false (default: false). Write JUnit results and
%                   Cobertura code coverage to test-results/, and raise an
%                   error if any test fails.
%
% Output:
%   results - matlab.unittest.TestResult array.
%
% Copyright (C) 2025 Brain Products GmbH

p = inputParser;
p.addParameter('Integration', true);
p.addParameter('CI', false);
p.parse(varargin{:});
opt = p.Results;

import matlab.unittest.TestRunner
import matlab.unittest.TestSuite
import matlab.unittest.plugins.XMLPlugin
import matlab.unittest.plugins.CodeCoveragePlugin
import matlab.unittest.plugins.codecoverage.CoberturaFormat

root     = fileparts(mfilename('fullpath'));
testsDir = fullfile(root, 'tests');

oldPath = path;
restorePath = onCleanup(@() path(oldPath));
addpath(root, testsDir);

suite = TestSuite.fromFolder(testsDir);
if ~opt.Integration
    suite = suite.selectIf(~matlab.unittest.selectors.HasTag('Integration'));
end

runner = TestRunner.withTextOutput;
if opt.CI
    outDir = fullfile(root, 'test-results');
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    runner.addPlugin(XMLPlugin.producingJUnitFormat(fullfile(outDir, 'junit.xml')));
    sources = fullfile(root, {'loadbvrf.m', 'eeg_loadbvrf.m', 'pop_loadbvrf.m', ...
        'evalRationalPolyAscending.m', 'safe_get.m', 'normalizeObjectArray.m', 'trimHeaderStrings.m'});
    runner.addPlugin(CodeCoveragePlugin.forFile(sources, ...
        'Producing', CoberturaFormat(fullfile(outDir, 'coverage.xml'))));
end

results = runner.run(suite);
disp(results);

if opt.CI
    assertSuccess(results);
end
end
