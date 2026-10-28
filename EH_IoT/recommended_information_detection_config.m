function cfg = recommended_information_detection_config(model,budget)
%RECOMMENDED_INFORMATION_DETECTION_CONFIG Measured joint-objective settings.
if nargin<1, model='paper'; end
if nargin<2, budget='quick'; end
cfg=information_detection_config(model,'quick');
path=fullfile(fileparts(mfilename('fullpath')),['output_joint_calibration_' model],'calibration.mat');
if exist(path,'file')
    saved=load(path,'calibration'); c=saved.calibration; cfg=c.selected_cfg;
    cfg.calibration.selected_rl=c.selected_rl; cfg.calibration.selected_dt=c.selected_dt;
    cfg.calibration.selection_objective=c.selection_objective;
    cfg.calibration.validation_N=c.validation_N;
    cfg.calibration.validation_steps=c.validation_steps;
    cfg.calibration.validation_trials=c.validation_trials;
end
cfg.save_results=true; cfg.save_learning_models=true; cfg.verbose=true;
cfg.dt.observable_feedback=true;
cfg.make_plots=true; cfg.capture_trace=true;
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=10000;
if strcmp(budget,'paper_budget')
    cfg.N_values=[10 25 50 75 100 125 150 175 200 225 250]; cfg.MCarlo=1000;
    cfg.rl.episodes=250; cfg.rl.steps=10000; cfg.rl.validation_steps=10000; cfg.rl.validation_trials=5;
    cfg.dt.data_episodes=12; cfg.dt.data_steps=10000; cfg.dt.updates=2000;
    cfg.dt.checkpoint_every=250; cfg.dt.rollout_validation_steps=10000; cfg.dt.rollout_validation_trials=5;
elseif ~strcmp(budget,'quick')
    error('Use quick or paper_budget.');
end
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_joint_test_' model]);
end
