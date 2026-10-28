function cfg = information_detection_config(model,budget)
%INFORMATION_DETECTION_CONFIG Joint Fig. 7 / Fig. 9 task, explicit model choice.
% 'paper' preserves 20x20 m and the E_B=1 Bernoulli reconstruction.
% 'archive_compatibility' uses 10x10 m and uniform EH from the supplied ZIP.
% Neither setting silently substitutes parameters to force a published curve.
if nargin<1, model='paper'; end
if nargin<2, budget='quick'; end
cfg=recommended_config(model,budget);
cfg.profile=['information_detection_' model '_' budget];
cfg.objective.miss_weight=1; % One normalized information unit per missed event.
cfg.rl.validation_metric='information_detection';
cfg.rl.validation_energy_weight=0;
cfg.rl.reward_mode='information_detection';
cfg.rl.sensing_penalty=0.02;
cfg.rl.mu1=10; cfg.rl.mu2=5;
cfg.rl.action_mode='coverage_rank'; cfg.dt.action_mode='coverage_rank';
cfg.rl.coverage_grid=16; cfg.dt.coverage_grid=16;
cfg.rl.learned_weight=0.15; cfg.dt.learned_weight=0.15;
cfg.rl.energy_weight=0.25; cfg.dt.energy_weight=0.25;
cfg.rl.energy_guard=true; cfg.dt.energy_guard=true;
cfg.rl.cap_groups_to_energy=true; cfg.dt.cap_groups_to_energy=true;
cfg.dt.cluster_scale=cfg.rl.cluster_scale;
cfg.dt.energy_margin=cfg.rl.energy_margin;
cfg.rl.episodes=12; cfg.rl.steps=1600;
cfg.rl.validation_steps=2000; cfg.rl.validation_trials=2;
cfg.dt.data_episodes=6; cfg.dt.data_steps=1600;
cfg.dt.data_epsilon_start=0.30; cfg.dt.data_epsilon_end=0.03;
cfg.dt.validation_epsilon=0.10;
cfg.dt.reuse_rl_teacher=true;
cfg.dt.updates=300; cfg.dt.patience=12;
cfg.dt.rollout_selection=true; cfg.dt.checkpoint_every=50;
cfg.dt.rollout_validation_steps=2000; cfg.dt.rollout_validation_trials=2;
cfg.dt.wake_threshold=0.20; cfg.dt.desired_return_quantile=0.75;
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_' cfg.profile]);
if strcmp(budget,'paper_budget')
    cfg.rl.episodes=250; cfg.rl.steps=10000;
    cfg.rl.validation_steps=10000; cfg.rl.validation_trials=5;
    cfg.dt.data_steps=10000; cfg.dt.data_episodes=12;
    cfg.dt.updates=2000; cfg.dt.checkpoint_every=250;
    cfg.dt.rollout_validation_steps=10000; cfg.dt.rollout_validation_trials=5;
end
end
