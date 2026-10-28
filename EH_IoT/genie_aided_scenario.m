%% Standalone closest-device genie with the same finite EH batteries.
clear; clc;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.methods={'genie'};
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_genie');
Results=run_experiments(cfg); plot_results(Results);
