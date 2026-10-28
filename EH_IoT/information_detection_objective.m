function score = information_detection_objective(metrics,cfg)
%INFORMATION_DETECTION_OBJECTIVE Dimensionless, declared validation utility.
% Misses are included as zero-information events in info_per_event already;
% the extra miss weight expresses a preference for detection reliability.
% Never uses published curve values. Energy is enforced by the simulator and
% feasible-action guard, rather than being a competing selection objective.
score=metrics.info_per_event/cfg.Psi-cfg.objective.miss_weight*metrics.misdetection;
if ~isfinite(score), score=-Inf; end
end
