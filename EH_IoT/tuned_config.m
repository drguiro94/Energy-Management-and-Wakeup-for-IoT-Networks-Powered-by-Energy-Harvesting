function cfg = tuned_config(model,budget)
%TUNED_CONFIG Stable learning settings, with explicit physical-model labels.
% 'paper' preserves Table III. 'archive_compatibility' changes ONLY the area
% and harvesting distribution to the source ZIP conventions; it is not Table III.
% The reporting metric/costs/range remain those of the journal model.
if nargin<1, model='paper'; end
if nargin<2, budget='quick'; end
cfg=paper_config('quick'); cfg.profile=['tuned_' model '_' budget];
switch model
    case 'paper'
        % Do not alter area, eta, lambda, quantum, costs, or range.
    case 'archive_compatibility'
        cfg.A=10; cfg.B=10; cfg.harvest_model='uniform';
    otherwise
        error('Use paper or archive_compatibility.');
end
cfg.methods={'random','cluster','rl','dt','genie'};
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=2000;
cfg.rl.action_mode='cluster_rank'; cfg.rl.cluster_scale=1;
cfg.rl.energy_guard=true; cfg.rl.energy_margin=2;
cfg.rl.validation_metric='information'; cfg.rl.validation_energy_weight=0.05;
cfg.rl.validation_trials=2; cfg.rl.validation_every=2;
cfg.rl.episodes=12; cfg.rl.steps=1200; cfg.rl.validation_steps=1200;
cfg.rl.mu1=20; cfg.rl.mu2=3;
cfg.rl.epsilon_start=0.8; cfg.rl.epsilon_end=0.03;
cfg.rl.patience=8;
cfg.rl.wake_credit='incremental'; cfg.rl.wake_discount=0;
cfg.rl.cap_groups_to_energy=true;
cfg.dt.action_mode='cluster_rank'; cfg.dt.cluster_scale=1;
cfg.dt.energy_guard=true; cfg.dt.energy_margin=2;
cfg.dt.balance_classes=true; cfg.dt.maximum_positive_weight=20;
cfg.dt.data_episodes=6; cfg.dt.baseline_episodes=0;
cfg.dt.data_steps=1200; cfg.dt.validation_epsilon=0.3;
cfg.dt.context=16; cfg.dt.d_model=32; cfg.dt.ff_size=64; cfg.dt.heads=4;
cfg.dt.updates=300; cfg.dt.batch_size=8; cfg.dt.learning_rate=0.001;
cfg.dt.validation_windows=24; cfg.dt.patience=10;
cfg.dt.wake_threshold=0.3; cfg.dt.desired_return_quantile=0.75;
cfg.dt.save_dataset=false;
cfg.dt.cap_groups_to_energy=true;
if strcmp(budget,'paper_budget')
    cfg.N_values=[10 25 50 75 100 125 150 175 200 225 250];
    cfg.MCarlo=1000; cfg.total=10000;
    cfg.rl.episodes=250; cfg.rl.steps=10000; cfg.rl.validation_steps=10000;
    cfg.rl.validation_trials=5;
    cfg.dt.data_episodes=12; cfg.dt.data_steps=10000;
    cfg.dt.updates=2000; cfg.dt.batch_size=16; cfg.dt.context=32;
elseif ~strcmp(budget,'quick')
    error('Use quick or paper_budget.');
end
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_' cfg.profile]);
end
