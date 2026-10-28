function cfg = paper_config(profile)
%PAPER_CONFIG All physical parameters and simulation controls in one place.
% Table III and Section VI of the uploaded journal paper define the physical
% parameters. 'paper' selects the stated evaluation budget.
if nargin < 1, profile = 'quick'; end
root = fileparts(mfilename('fullpath'));
cfg.profile = profile;
cfg.seed = 20261027;
cfg.A = 10; cfg.B = 10;           % Rectangular monitored area [m x m]
cfg.TTI = 1;                     % Normalized slot duration tau
cfg.N_values = [10 50 100 250];
cfg.MCarlo = 3;
cfg.total = 2000;                % Measured TTIs per independent deployment
cfg.burn_in = 0;                 % Extra unmeasured TTIs; paper specifies none
cfg.alpha = 0.1;                 % Bernoulli event probability per TTI
cfg.lambda = 0.1;                % EH arrival rate, not the arrival probability
cfg.E_B = 1;                     % Fixed energy quantum per active EH slot
cfg.E_max = 100;
cfg.initial_battery = 100;       % Scalar, or 'uniform' on [0,E_max]
cfg.idle_E = 1;
cfg.Tx_E = 10;
cfg.wake_up_Energy = 1/14;        % Sleep/WuR energy per IoTD per TTI
cfg.eta = 1; cfg.Psi = 1;
cfg.active_distance = 4;         % d_max [m]
cfg.harvest_model = 'bernoulli_fixed'; % P(arrival)=1-exp(-lambda*TTI)
cfg.detection_model = 'range';   % Supplied check_active.m convention
cfg.aggregation = 'max';         % Journal information model: max_j I_ij
cfg.deployment = 'uniform';      % PPP.m conditional on a fixed device count
cfg.methods = {'random','adjusted','cluster','genie'};
cfg.random_cycles = [2 4 8];
cfg.random_on_times = [1 2];
cfg.adjusted_cycles = [2 4 8 16 32 64];
cfg.adjusted_on_times = [1 2];
cfg.search_total = 600;          % Independent pilot TTIs per search candidate
cfg.search_MCarlo = 2;           % Separate pilot streams; no test-set tuning
cfg.cluster_replicates = 3;
cfg.cluster_iterations = 80;
cfg.angle_samples = 32;          % Uniform-angle integration of Eqs. (14)-(15)
cfg.genie_ignore_battery = false;% true creates an ideal information bound
cfg.make_plots = true;
cfg.figure_visible = 'off';
cfg.figure_formats = {'png'};    % Add 'eps' for editable vector plot exports
cfg.output_dir = fullfile(root, ['output_' profile]);
cfg.verbose = true;
cfg.save_results = true;
cfg.resume = false;              % true resumes a compatible checkpoint
cfg.checkpoint_every = 25;       % Independent deployments, not TTIs
cfg.capture_trace = true;
cfg.trace_devices = 5;

% Optional, newly reconstructed parameter-sharing Q-learning reference.
cfg.rl.episodes = 4; cfg.rl.steps = 1200;
cfg.rl.learning_rate = 0.01; cfg.rl.discount = 0.95;
cfg.rl.epsilon_start = 1; cfg.rl.epsilon_end = 0.05;
cfg.rl.mu1 = 10; cfg.rl.mu2 = 2;
cfg.rl.score_decay = 0.9;
cfg.rl.validation_every = 2;
cfg.rl.validation_steps = 300;
cfg.rl.patience = 6;
cfg.rl.minimum_improvement = 0.001;
cfg.rl.action_mode = 'independent'; % 'cluster_rank' prevents synchronized actions
cfg.rl.cluster_scale = 1;
cfg.rl.energy_guard = false; cfg.rl.energy_margin = 0;
cfg.rl.validation_metric = 'reward';
cfg.rl.validation_trials = 1; cfg.rl.validation_energy_weight = 0;
cfg.rl.wake_credit='global'; cfg.rl.wake_discount=0.95;
cfg.rl.cap_groups_to_energy=false;
cfg.collect_learning = false;    % Internal offline trajectory collection
cfg.save_learning_models = true;

% Reconstructed decision transformer: joint N-device binary outputs, causal
% context, return-to-go conditioning, and fully trainable attention/FFNs.
cfg.dt.context=16; cfg.dt.d_model=16; cfg.dt.heads=2;
cfg.dt.blocks=2; cfg.dt.ff_size=32;
cfg.dt.data_episodes=4; cfg.dt.data_steps=400;
cfg.dt.baseline_episodes=2;
cfg.dt.updates=120; cfg.dt.batch_size=8; cfg.dt.learning_rate=0.001;
cfg.dt.gradient_clip=1; cfg.dt.validation_every=10;
cfg.dt.validation_windows=16; cfg.dt.patience=6;
cfg.dt.validation_epsilon=0.35;   % Independent behavior rollout with varied actions
cfg.dt.minimum_improvement=0.001;
cfg.dt.desired_return_quantile=0.9;
cfg.dt.save_dataset=true;
cfg.dt.action_mode='independent'; cfg.dt.cluster_scale=1;
cfg.dt.energy_guard=false; cfg.dt.energy_margin=0;
cfg.dt.balance_classes=false; cfg.dt.maximum_positive_weight=20;
cfg.dt.wake_threshold=0.5;
cfg.dt.teacher_episodes=0;       % 0 uses the RL episode count
cfg.dt.minimum_wake_train=0; cfg.dt.minimum_wake_validation=0;
cfg.dt.cap_groups_to_energy=false;
cfg.dt.observable_feedback=true; % Never feed hidden missed events into online history.

switch lower(profile)
    case 'quick'
        % Physical parameters above are unchanged; only sample counts shrink.
    case 'paper'
        cfg.N_values = [10 25 50 75 100 125 150 175 200 225 250];
        cfg.MCarlo = 1000; cfg.total = 10000;
        cfg.search_total = 10000; cfg.search_MCarlo = 5;
        cfg.rl.episodes = 250; cfg.rl.steps = 10000;
    case 'archive'
        % Corrected conference-like setting. This is not a literal rerun of
        % the buggy archive, nor a parameter set from journal Table III.
        cfg.A = 10; cfg.B = 10; cfg.active_distance = 5;
        cfg.harvest_model = 'uniform'; % Original EH_random(...,1,1)
        cfg.wake_up_Energy = 1/20;
        cfg.aggregation = 'sum';       % Original sum(BS_info)
    otherwise
        error('Unknown profile: %s. Use quick, paper, or archive.', profile);
end
end
