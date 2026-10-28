function policy = train_q_reference(policy,dev,cfg,seed)
%TRAIN_Q_REFERENCE NEW baseline reconstructed from Eqs. (23)-(24).
% One shared table controls binary idle/sleep actions. Additional wakeups use
% the separately labeled greedy mu2 rule in simulate_network, not a second
% unpublished RL agent. No claim of reproducing the paper's RL/DT curves.
train_cfg=cfg; train_cfg.total=cfg.rl.steps; train_cfg.burn_in=0;
train_cfg.capture_trace=false;
history=zeros(cfg.rl.episodes,3);
for e=1:cfg.rl.episodes
    progress=(e-1)/max(1,cfg.rl.episodes-1);
    policy.epsilon=cfg.rl.epsilon_start*(1-progress)+cfg.rl.epsilon_end*progress;
    scenario=make_scenario(train_cfg,size(dev,1),seed+50000+e,dev);
    [m,~,policy]=simulate_network(train_cfg,scenario,policy,true);
    history(e,:)=[m.reward m.info_per_event m.energy_actual];
end
policy.training_history=history; policy.epsilon=0;
end
