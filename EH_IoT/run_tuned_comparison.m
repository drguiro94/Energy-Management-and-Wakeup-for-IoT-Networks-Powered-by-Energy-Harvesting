%% CALIBRATE RL/DT, THEN EVALUATE ON NEW DEPLOYMENTS AND TEST STREAMS
% No figure values enter the search. Use the profile that matches the intended
% physical experiment; the two profiles must never be presented as identical.
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
model='paper'; % Or 'archive_compatibility': 10x10 m + uniform [0,1] EH
calibration=tune_rl_dt(model,'quick');
cfg=calibration.selected_cfg;
cfg.save_results=true; cfg.save_learning_models=true; cfg.verbose=true;
cfg.make_plots=true; cfg.capture_trace=true;
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=10000;
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_tuned_test_' model]);
Results=run_experiments(cfg);
plot_information_curve(Results); plot_learning(Results);
fprintf('Calibration and independent testing complete: %s\n',cfg.output_dir);
