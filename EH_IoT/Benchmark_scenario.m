%% Standalone random-duty-cycle benchmark.
clear; clc;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.methods={'random'};
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_benchmark');
Results=run_experiments(cfg); plot_results(Results);
