function policy = train_two_stage_rl(policy,dev,cfg,seed)
%TRAIN_TWO_STAGE_RL Two shared Q tables, with an explicit idle reward mode.
% The original mode uses Eqs. (24)-(25). The joint task mode extends Eq. (24)
% to value information and missed-event reliability together.
% Idle decisions learn at every TTI. Extra-report decisions learn at detected
% events that have eligible sleeping neighbors; those are separate clocks.
% Validation episodes have disjoint seeds and never update the Q tables.
c=cfg; c.total=cfg.rl.steps; c.burn_in=0; c.capture_trace=false;
c.collect_learning=false;
history=NaN(cfg.rl.episodes,7); best=-Inf; stale=0; best_policy=policy;
for e=1:cfg.rl.episodes
    p=(e-1)/max(1,cfg.rl.episodes-1);
    policy.epsilon=cfg.rl.epsilon_start*(1-p)+cfg.rl.epsilon_end*p;
    scenario=make_scenario(c,size(dev,1),seed+60000+e,dev);
    [m,~,policy]=simulate_network(c,scenario,policy,true);
    history(e,:)=[e m.reward m.wake_reward m.info_per_event m.energy_actual NaN m.wake_decision_count];
    if mod(e,cfg.rl.validation_every)==0 || e==cfg.rl.episodes
        validation=c; validation.total=cfg.rl.validation_steps;
        objectives=zeros(cfg.rl.validation_trials,1);
        for trial=1:cfg.rl.validation_trials
            holdout=make_scenario(validation,size(dev,1),seed+90000+trial,dev);
            v=simulate_network(validation,holdout,policy,false);
            objectives(trial)=validation_objective(v,cfg);
        end
        objective=mean(objectives); history(e,6)=objective;
        if objective>best+cfg.rl.minimum_improvement*max(1e-8,abs(best)) || ~isfinite(best)
            best=objective; best_policy=policy; stale=0;
        else
            stale=stale+1;
        end
        if stale>=cfg.rl.patience, break; end
    end
end
policy=best_policy; policy.epsilon=0;
policy.training_history=history(1:e,:);
policy.training_history_columns={'episode','idle_reward','wake_reward','information','energy','validation_objective','wake_decisions'};
policy.training_seed=seed; policy.validation_objective=best;
end
