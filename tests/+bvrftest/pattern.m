function data = pattern(nChan, nSamp)
% bvrftest.pattern - Deterministic test signal: data(c, s) = 1000*c + (s-1).
%
% Every value identifies its channel and its 1-based sample index, so tests
% can check channel order and sample offsets exactly. Values stay within the
% int16 range for nChan <= 30 and nSamp <= 1000.
data = (1:nChan)' * 1000 + (0:nSamp-1);
end
