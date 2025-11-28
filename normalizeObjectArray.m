function [objs, errors] = normalizeObjectArray(obj, path)
%NORMALIZEOBJECTARRAY Normalize JSON array-of-objects to cell array of structs.
%
%   Input:
%       obj  - result of jsondecode for some JSON array
%       path - string used for error messages, e.g. 'EEGModality.Electrodes'
%
%   Output:
%       objs   - cell array of structs (each element one object)
%       errors - cell array of error strings (empty if ok)

errors = {};
objs   = {};

if isstruct(obj)
    % jsondecode returned a struct array: one struct per element
    if isempty(obj)
        errors{end+1} = sprintf('"%s" must be a non-empty array of objects.', path);
        return;
    end
    objs = num2cell(obj); % 1xN cell, each a scalar struct
    return;
end

if iscell(obj)
    if isempty(obj)
        errors{end+1} = sprintf('"%s" must be a non-empty array of objects.', path);
        return;
    end
    % Check all elements are structs
    for i = 1:numel(obj)
        if ~isstruct(obj{i})
            errors{end+1} = sprintf('"%s{%d}" must be an object.', path, i);
        end
    end
    objs = obj;
    return;
end

% Anything else is wrong (numeric, string, etc.)
errors{end+1} = sprintf('"%s" must be an array of objects (struct array or cell array).', path);
end
