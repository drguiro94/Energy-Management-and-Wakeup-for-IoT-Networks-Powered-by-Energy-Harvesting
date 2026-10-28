%% Standalone spatial cluster policy.
clear; clc;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.methods={'cluster'};
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_cluster');
Results=run_experiments(cfg); plot_results(Results); plot_system_model(Results);
