%% FIG. 7 FOCUS: MEAN INFORMATION PER EVENT
% This default uses the ORIGINAL ZIP'S area/EH conventions explicitly.
% It is a plausible information-level reconstruction, not Table III's area.
% Switch to model='paper' for 20x20 m and the explicit E_B=1 Bernoulli setup.
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
model='archive_compatibility'; % 10x10 m; uniform [0,1] harvested units / TTI
cfg=recommended_config(model);
cfg.methods={'random','cluster','rl','dt','genie'};
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=10000;
% For a denser Fig. 7 sweep:
% cfg.N_values=[10 25 50 75 100 125 150 175 200 225 250];
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),['output_information_' model]);
Results=run_experiments(cfg);
plot_information_curve(Results);
fprintf('Information-per-event outputs: %s\n',cfg.output_dir);
