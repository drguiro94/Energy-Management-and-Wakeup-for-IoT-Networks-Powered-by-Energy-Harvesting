%% MAXIMIZE INFORMATION PER EVENT AND MINIMIZE MISDETECTIONS
% Select the PHYSICAL MODEL explicitly. Learning settings never alter it.
% 'paper': 20x20 m, Bernoulli EH, with the stated E_B=1 reconstruction.
% 'archive_compatibility': 10x10 m and uniform EH from the supplied ZIP.
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
model='paper';
cfg=recommended_information_detection_config(model);
cfg.methods={'random','cluster','rl','dt','genie'};
cfg.N_values=[10 50 250]; cfg.MCarlo=3; cfg.total=10000;
% Optional dense sweep: cfg.N_values=[10 25 50 75 100 125 150 175 200 225 250];
% Optional new search with independent validation streams:
% tune_information_detection(model,'quick');
% cfg=recommended_information_detection_config(model);
Results=run_experiments(cfg);
plot_information_detection(Results);
fprintf('Information and misdetection outputs: %s\n',cfg.output_dir);
