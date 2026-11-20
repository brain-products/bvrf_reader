% trimHeaderStrings() - Remove leading and trailing whitespace from every
%                       text value in a decoded BVRF header.
%
% Usage:
%       >> hdr = trimHeaderStrings(hdr)
%
% Input:
%   hdr - Header as returned by jsondecode (struct, struct array, cell
%         array, char or string, nested to any depth).
%
% Output:
%   hdr - Same structure, with strtrim applied to every char/string value.
%         Spaces inside values (e.g. "Seeing stuff") are kept; only
%         invisible leading/trailing whitespace that would break matching
%         of names and ids (e.g. "Fp1 " vs "Fp1") is removed. Numbers,
%         logicals and field names are left unchanged.
%
% Author: Ramon Martinez-Cancino, Brain Products GmbH, 2025
%
% Copyright (C) 2025 Brain Products GmbH
%
% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in all
% copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
function x = trimHeaderStrings(x)

if ischar(x) || isstring(x)
    x = strtrim(x);
elseif isstruct(x)
    fields = fieldnames(x);
    for k = 1:numel(x)
        for f = 1:numel(fields)
            x(k).(fields{f}) = trimHeaderStrings(x(k).(fields{f}));
        end
    end
elseif iscell(x)
    for k = 1:numel(x)
        x{k} = trimHeaderStrings(x{k});
    end
end
end
