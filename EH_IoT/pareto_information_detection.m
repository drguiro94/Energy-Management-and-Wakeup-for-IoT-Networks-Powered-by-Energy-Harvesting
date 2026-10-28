function keep = pareto_information_detection(information,miss)
%PARETO_INFORMATION_DETECTION True for non-dominated measured candidates.
% A dominates B only if its information is at least as high, its miss rate
% is no higher, and at least one inequality is strict. No scalar-score trick
% can hide the underlying tradeoff in the exported search evidence.
information=information(:); miss=miss(:); valid=isfinite(information)&isfinite(miss); keep=valid;
for b=1:numel(keep)
    if ~keep(b), continue; end
    dominates=valid & information>=information(b) & miss<=miss(b) & ...
        (information>information(b) | miss<miss(b));
    dominates(b)=false;
    if any(dominates), keep(b)=false; end
end
end
