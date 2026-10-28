%% COMPLETE RECONSTRUCTED RL AND DECISION-TRANSFORMER EXPERIMENT
% Start here for the learning methods. Both decision stages are implemented.
% Base MATLAB only: no Deep Learning / Reinforcement Learning Toolbox.
% These are new implementations from the paper, not recovered author weights.
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
model='paper'; % Or 'archive_compatibility': explicitly 10x10 m, uniform EH.
cfg=recommended_information_detection_config(model,'quick');

%% Calibrated settings; the stated physical model is kept explicit.
cfg.methods={'random','cluster','rl','dt','genie'};
% Add 'adjusted' to include the separately tuned duty-cycle baseline.
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=10000;
cfg.search_total=200; cfg.search_MCarlo=1;
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_rl_dt_joint_' model]);
% Paper-size RL budget: cfg.rl.episodes=250; cfg.rl.steps=10000;
% Paper-size evaluation: cfg.MCarlo=1000; cfg.total=10000;
% DT data, architecture, and optimizer controls are explicit in paper_config.

%% Train on independent streams, freeze policies, and evaluate common inputs.
Results=run_experiments(cfg);
plot_information_detection(Results); plot_learning(Results);
fprintf('\nRL/DT experiment complete: %s\n',cfg.output_dir);
