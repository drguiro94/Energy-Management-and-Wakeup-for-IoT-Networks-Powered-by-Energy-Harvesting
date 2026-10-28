%% Full Monte Carlo budget stated in Section VI (can take a long time).
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('paper');
% cfg.resume=true; % Resume checkpoint.mat with identical physical settings.
Results=run_experiments(cfg);
plot_results(Results); plot_system_model(Results);
