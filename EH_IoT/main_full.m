%% ENERGY MANAGEMENT AND WAKEUP FOR ENERGY-HARVESTING IoT NETWORKS
% Start here. No input files, toolboxes, or precomputed results are required.
% The original archive's MATLAB script + helper-function format is retained.
% See README.md and MODEL_NOTES.md for the source/paper differences.
clear; clc; close all;
project_folder = fileparts(mfilename('fullpath'));
addpath(project_folder);

%% 1. Select the simulation size
cfg = paper_config('archive');       % 'quick', 'paper', or 'archive'
% cfg = paper_config('paper');     % 1000 deployments x 10000 TTIs per N
% cfg.N_values = [10 25 50 75 100 125 150 175 200 225 250];
% cfg.MCarlo = 25;
% cfg.total = 10000;
% cfg.detection_model = 'bernoulli'; % Literal alpha*p(d) transition model
% cfg.methods{end+1} = 'q_reference';% NEW reference implementation, not
                                    % the missing published RL training code
% For complete reconstructed RL + DT pipelines, run run_rl_dt.m instead.

%% 2. Simulate new deployments, events, harvesting, and battery trajectories
Results = run_experiments(cfg);

%% 3. Plot only values measured in this run
plot_results(Results);
plot_system_model(Results);
fprintf('\nFinished. Results and figures: %s\n', cfg.output_dir);
