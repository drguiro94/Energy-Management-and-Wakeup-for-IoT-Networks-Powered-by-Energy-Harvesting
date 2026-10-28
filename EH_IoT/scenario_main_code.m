%% Standalone adjusted duty cycling with sequential on-demand wakeups.
clear; clc;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.methods={'adjusted'};
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_adjusted');
Results=run_experiments(cfg); plot_results(Results);
