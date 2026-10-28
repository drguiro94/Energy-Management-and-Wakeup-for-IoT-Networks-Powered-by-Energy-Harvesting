function reward = idle_task_reward(information,event,awake,N,cfg)
%IDLE_TASK_REWARD Keep paper reward and task-focused shaping explicitly apart.
% The simulator can provide missed-event labels during TRAINING. Neither the
% label nor the current event enters the action chosen before that event.
% Paper Eq. (24) remains the default for existing configurations/models.
if isfield(cfg.rl,'reward_mode') && strcmp(cfg.rl.reward_mode,'information_detection')
    % Stage one must value received information as well as initial detection.
    % The event penalty is conditional on a real event; no extra alpha factor
    % weakens it. This is an explicit task-focused extension to Eq. (24).
    reward=double(event)*(cfg.rl.mu2*information/cfg.Psi-...
        cfg.rl.mu1*double(information==0))-cfg.rl.sensing_penalty*awake/N;
else
    reward=1-awake/N-cfg.alpha*cfg.rl.mu1*double(event && information==0);
end
end
