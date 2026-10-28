function value = validation_objective(metrics,cfg)
%VALIDATION_OBJECTIVE Choose checkpoints using a stated task-level objective.
% Information selection follows the primary reporting goal, not a paper-curve
% target. An optional small measured-energy cost has explicit configuration.
if strcmp(cfg.rl.validation_metric,'information_detection')
    value=information_detection_objective(metrics,cfg);
elseif strcmp(cfg.rl.validation_metric,'information')
    value=metrics.info_per_expected_event-cfg.rl.validation_energy_weight*metrics.energy_actual;
else
    value=metrics.reward+metrics.wake_reward;
end
if ~isfinite(value), value=-1e6; end
end
