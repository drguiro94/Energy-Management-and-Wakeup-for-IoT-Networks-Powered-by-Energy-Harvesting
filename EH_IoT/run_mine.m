clear; clc; close all;

% 1. Load the physical model and selected learning settings.
% 'paper':                 20x20 m, Bernoulli harvesting
% 'archive_compatibility': 10x10 m, uniform harvesting
cfg = recommended_information_detection_config('archive_compatibility');

% 2. Methods to compare.
% Keep RL before DT so DT can reuse the frozen RL teacher.
% cfg.methods = {'random','cluster','rl','dt','genie'};

% To include adjusted duty cycling, use instead:
cfg.methods = {'random','adjusted','cluster','rl','dt','genie'};

% 3. FINAL EVALUATION.
cfg.N_values = [10 50 100 250];  % Device counts
cfg.MCarlo = 2;             % Independent deployments per device count
cfg.total = 10000;          % Test slots per deployment

% 4. RL TRAINING.
cfg.rl.episodes = 8;
cfg.rl.steps = 1600;
cfg.rl.learning_rate = 0.01;
cfg.rl.mu1 = 5;             % Missed-event penalty
cfg.rl.mu2 = 5;             % Information reward

% 5. DT OFFLINE DATA AND TRAINING.
cfg.dt.data_episodes = 6;
cfg.dt.data_steps = 1600;
cfg.dt.context = 16;        % Number of past decision instants
cfg.dt.updates = 200;       % Maximum optimizer updates per stage
cfg.dt.learning_rate = 0.001;

% 6. MODEL-SELECTION PREFERENCE.
cfg.objective.miss_weight = 1;

% 7. OUTPUT.
cfg.output_dir = fullfile(pwd,'output_mine');
cfg.figure_visible = 'on';  % Show figures as well as saving them
cfg.resume = false;

% Inspect effective settings.
disp(cfg.rl);
disp(cfg.dt);
disp(cfg.objective);

% 8. Train, select checkpoints, and evaluate frozen policies.
Results = run_experiments(cfg);

% Main outcomes and training histories.
plot_information_detection(Results);
plot_learning(Results);

% Optional: broader metrics and physical-model illustrations.
% plot_results(Results);
% plot_system_model(Results);