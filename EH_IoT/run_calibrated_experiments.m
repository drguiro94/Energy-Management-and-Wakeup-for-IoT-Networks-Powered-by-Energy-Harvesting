%% CALIBRATE RL/DT PARAMETERS, THEN RUN THE FULL COMPARISON
% Run this script from the EH_IoT folder.
% First run: performs a new finite parameter search, then final experiments.
% Later runs: reuse the SAME completed calibration; resume completed trials.
% The search varies every RL/DT field in the earlier manual training blocks.
% Fixed physical assumptions and the declared miss preference are not tuned.
% No toolbox or pretrained policy is required.
clear; clc; close all;
project_folder=fileparts(mfilename('fullpath'));
addpath(project_folder);

%% 1. Physical model and recommended starting controls
% 'paper': 20x20 m, Bernoulli EH.
% 'archive_compatibility': 10x10 m, uniform EH.
model='archive_compatibility';
base=recommended_information_detection_config(model,'paper_budget');

% A substantial pilot budget for the adjusted-duty baseline.
base.search_total=10000;
base.search_MCarlo=5;

%% 2. Calibration: independent from the final deployments and test streams
search.model=model;
search.N_values=[10 50 100 250];
search.deployments=2;           % Independent calibration geometries per N
search.validation_steps=10000;
search.validation_trials=2;     % Event/EH streams per geometry
search.checkpoint_steps=10000;  % Internal RL/DT checkpoint-validation slots
search.checkpoint_trials=3;
search.rl_candidates=12;
search.dt_candidates=12;
search.miss_weight=1;           % Declared reliability preference
search.output_dir=fullfile(project_folder, ...
    ['output_parameter_calibration_' model]);
search.force=false;            % true backs up old evidence and recalibrates
search.plan_only=false;        % true prints candidates without training/testing

% Search levels are documented in calibrate_learning_parameters.m.
% To preview candidates without training, call the helper separately with:
% preview=search; preview.plan_only=true;
% plan=calibrate_learning_parameters(base,preview);

calibration=calibrate_learning_parameters(base,search);
if search.plan_only
    for k=1:numel(calibration.rl_candidates)
        fprintf('\nRL candidate %d\n',k); disp(calibration.rl_candidates{k}.rl);
    end
    for k=1:numel(calibration.dt_candidates)
        fprintf('\nDT candidate %d\n',k); disp(calibration.dt_candidates{k}.dt);
    end
    return;
end
assert(strcmp(calibration.status,'complete'),'Calibration must finish first.');

%% 3. Use the actual selected configuration; no manual RL/DT overrides
cfg=calibration.selected_cfg;
cfg.methods={'random','adjusted','cluster','rl','dt','genie'};

%% 4. Final evaluation (these controls do not select learning parameters)
cfg.N_values=[10 50 100 150 250];
cfg.MCarlo=100;
cfg.total=10000;
cfg.output_dir=fullfile(project_folder,['output_calibrated_main_' model]);
cfg.figure_visible='on';
cfg.resume=true;                % Resume only an identical final experiment
cfg.checkpoint_every=1;          % Save after each complete deployment

% Keep the selected learning settings exactly as loaded.
disp(cfg.rl);
disp(cfg.dt);
disp(cfg.objective);
disp(cfg.calibration);

%% 5. Train fresh deployment-specific models, freeze, and test common streams
Results=run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);

% Optional broader physical/energy plots:
% plot_results(Results);
% plot_system_model(Results);
fprintf('\nFinal results: %s\n',cfg.output_dir);

