# EH-IoT code guide: system model, methods, files, and parameters

For configuration changes, start with [Section 6](#6-where-to-configure-parameters): [find profile values](#61-exactly-where-paper-and-archive_compatibility-are-defined), [print effective settings](#62-print-and-compare-the-actual-values-before-running), and [apply modifications](#63-apply-changes-in-your-own-experiment-script).

## 1. Intro

Battery-powered sensors watching an area. Events occur at different places. A sensor near an event can send useful information, but being awake and transmitting use energy. Sleeping saves energy, and a low-power wakeup receiver lets the base station ask for an extra report. Harvesting replenishes batteries over time.

The controller has two decisions:

1. **Before knowing whether an event occurs:** which sensors should be awake?
2. **After receiving a real report:** which sleeping sensors should be asked for extra reports?

The first decision affects whether an event is detected at all. The second can improve information about an already detected event. **If nobody sends an initial report, the practical methods cannot start the extra-report stage to rescue that missed event.**

Every method uses the same physical simulator. Their difference is how they choose the awake sensors and extra-report requests.

## 2. Which script should I run?

Extract the ZIP and make `EH_IoT_clean` your MATLAB current folder. Base MATLAB R2016b or newer is the intended target; GNU Octave 8.4.0 was used for the delivered checks. No Deep Learning, Reinforcement Learning, Statistics, or Parallel Computing Toolbox is required. No Python, input dataset, or pretrained model is needed for a normal MATLAB run.

| Entry point | What it does | Default methods |
| --- | --- | --- |
| `main_full.m` | Runs the heuristic/baseline comparison and broad system/result plots. | `random`, `adjusted`, `cluster`, `genie` |
| `run_rl_dt.m` | Trains fresh RL and DT policies, evaluates them with baselines, and plots information, misses, and training histories. | `random`, `cluster`, `rl`, `dt`, `genie` |
| `run_information_detection_experiment.m` | Runs the current joint information/missed-event experiment. | The same five methods as `run_rl_dt` |
| `run_paper.m` | Uses the large Monte Carlo budget: 1000 deployments and 10000 test slots per device count. It still runs the baseline method list unless you change it. | `random`, `adjusted`, `cluster`, `genie` |
| `Benchmark_scenario.m` | Runs only the random duty-cycle benchmark. | `random` |
| `scenario_main_code.m` | Runs only adjusted duty cycling and heuristic extra reports. | `adjusted` |
| `scenario_kmeans.m` | Runs only spatial clustering and heuristic extra reports. | `cluster` |
| `genie_aided_scenario.m` | Runs only the closest-device genie. | `genie` |
| `run_sensitivity.m` | Sweeps event probability for the available practical baseline policies. | See its method list |
| `run_information_experiment.m` | Runs the earlier information-only experiment; its default is the alternate 10 m model. | See its method list |
| `run_tuned_comparison.m` | Runs the older information-only search and independent comparison. | See its method list |
| `run_reproduction_audit.m` | Checks physical information/energy limits; it is not a training experiment. | No learned comparison |

Quick starts:

```matlab
main_full                    % Baselines and physical-model plots
% Or:
run_rl_dt                    % Baselines + freshly trained RL and DT
% Or:
run_information_detection_experiment
```

Run one entry point at a time.

### Does main_full run the conference, and run_rl_dt add RL/DT?

`main_full` retains the baseline/scenario organization of the conference archive, but its default `paper_config('quick')` uses the journal-model reconstruction. It is **not a literal rerun of the original conference code**.

`run_rl_dt` is a separate complete experiment. It does not need `main_full` to run first, does not append to a previous `Results` object, and does not automatically reuse previously saved trained models.

To compare all six main methods in one experiment, put this before `run_experiments(cfg)`:

```matlab
cfg.methods = {'random','adjusted','cluster','rl','dt','genie'};
```

Keep `rl` before `dt` when `cfg.dt.reuse_rl_teacher=true` so the DT can reuse the frozen RL teacher trained for that deployment. Including `adjusted` adds its pilot-search cost.

## 3. What happens during one simulation slot?

The central file is `simulate_network.m`. A TTI is one simulation time slot.

1. The controller chooses which sensors should be awake using information available before the current event.
2. Awake sensors pay the idle/sensing cost; sleeping sensors pay the wakeup-receiver cost.
3. If an event occurs, nearby awake sensors try to transmit. A transmission succeeds only if the sensor has enough actual battery energy.
4. If at least one report arrives, methods that support extra reports can request sleeping sensors. These requests use energy and may improve the final information.
5. Energy is harvested at the end of the slot and clipped to battery capacity.
6. The simulator records information, missed events, energy, batteries, and other diagnostics.

Extra-report requests occur within that slot: they do not create another event or another harvest opportunity.

The simulator knows the event and true batteries because it must simulate physics and score outcomes. Practical RL/DT action inputs use observations/history and battery estimates, not the unseen current event, true unreported sleeping-device batteries, or future harvests. The genie is the explicitly privileged exception.

### Information and missed events

A successful report at distance `d` carries information `Psi * exp(-eta*d)` within the sensing range. Outside the range, it carries no information.

The recommended setting is `cfg.aggregation='max'`: the event's final information is the strongest successful report. More reports can improve the maximum; they do not simply add together. Other selectable modes are saturated sum and the archive's uncapped sum.

The main task metrics are:

- **Information per actual event:** total delivered information divided by the actual number of events. Missed events remain in the denominator with zero information.
- **Missed-event fraction:** events with zero delivered information divided by the actual number of events. Plots multiply this fraction by 100.
- **Information per expected event:** total information divided by `alpha * number_of_test_slots`, the Eq. (18) normalization. This is saved separately.

If a run has no events, actual-event ratios are undefined and recorded as `NaN`.

## 4. What each method does

### Random duty cycling — random

Each sensor receives a randomly selected cycle length, awake-window length, and starting phase. It then follows that fixed repeating schedule.

This method does not learn or tune a schedule from outcomes. In this implementation, it does not request extra reports.

**Main files:** `build_policy.m` creates the schedule; `check_idle.m` advances it; `simulate_network.m` executes it.

**Parameters:** `cfg.random_cycles` and `cfg.random_on_times`.

### Adjusted duty cycling — adjusted

This method tries candidate cycle lengths and awake-window lengths on independent pilot event/harvest streams for the current deployment.

It compares each candidate's mean information per expected event with a geometric target derived from bounded Voronoi cells. Among candidates that meet the target, it chooses the one using the least measured energy. If none meets the target, it chooses the highest-information candidate, breaking ties by energy, and records that the target was infeasible.

After an initial report, it ranks sleeping candidates using report-based spatial correlation. It requests one sensor at a time and recomputes the ranking after each outcome, stopping at the target or when no eligible candidates remain.

This is a pilot search over fixed schedules, not RL. Its search rule is not automatically replaced by the joint RL/DT objective.

**Main files:** `build_policy.m`, especially `select_duty_cycle`; `voronoi_information_target.m`; `wake_close_device.m`; `correlation_lookup.m`; `simulate_network.m`.

**Parameters:** `cfg.adjusted_cycles`, `cfg.adjusted_on_times`, `cfg.search_total`, `cfg.search_MCarlo`.

### Spatial clustering — cluster

Sensors are grouped by their positions using the archive's k-means approach. The default number of groups is based on `ceil(area / (pi * sensing_range^2))` and cannot exceed the number of sensors.

Within each group, sensors take turns being awake. The planned schedule gives each group one awake sensor per slot, although an energy shortage can prevent actual sensing/reporting. After an initial report, the same sequential, report-conditioned heuristic used by the adjusted method can request extra reports.

The journal describes a KNN-based method; the supplied source uses k-means. This package labels the implemented source method accordingly.

**Main files:** `kmeans_cluster.m`, `check_idle.m`, `wake_close_device.m`, `simulate_network.m`.

**Parameters:** sensing range/area determine the default grouping; `cfg.cluster_replicates` and `cfg.cluster_iterations` control k-means. The RL/DT `cluster_scale` controls are separate from this baseline.

### Genie — genie

The genie knows whether and where the current event occurs. It activates the nearest sensor within range and does not need to discover the event through an initial practical report.

By default, the selected sensor still has a finite battery. Therefore, the finite-battery genie is a privileged comparator, not a guaranteed upper bound on every individual sample path: its nearest sensor can be depleted.

`cfg.genie_ignore_battery=true` creates an ideal information comparator that ignores battery failures. Keep its label distinct from the finite-battery version.

**Main files:** the `genie` branches in `build_policy.m` and `simulate_network.m`.

### Simplified shared-Q reference — q_reference

This older reference learns only sleep/awake decisions with one shared Q table. Extra-report requests use a separate greedy estimated-gain rule.

It remains available as an optional comparison. Use `rl` for the complete two-stage learner.

**Main files:** `train_q_reference.m`, `q_state.m`, `simulate_network.m`.

### Two-stage reinforcement learning — rl

RL learns by trying actions in the simulator and receiving rewards. In easy words: it keeps a table of how useful each action has been in a particular situation.

There are two tables, each `1440 x 2`:

| Table | When used | Two actions |
| --- | --- | --- |
| `policy.q_idle` | Before an event, every slot | Sleep / be awake |
| `policy.q_wake` | After initial reports, when sleeping candidates are eligible | Do not request / request |

These are shared tables: sensors with the same discretized local state use the same table entries. They are not one separate Q table per sensor.

The local state summarizes estimated battery, observed/inferred sensing score, previously received information, active-neighbor count, prior awake action, and deployment density. `q_state.m` bins those quantities into 1440 possibilities.

The training process is:

1. Generate a fresh training event/harvest stream on the deployment.
2. Explore some actions instead of always taking the current preferred action.
3. Simulate their consequences.
4. Update the Q values toward observed reward plus the discounted value of the next state.
5. Periodically evaluate the current tables on separate validation streams.
6. Retain the best validation checkpoint, then freeze it for final testing.

`train_two_stage_rl.m` manages episodes, exploration, validation, and early stopping. The actual Q updates occur inside `simulate_network.m` using `shared_q_update.m`. Simultaneous updates to the same shared table cell are averaged to avoid sensor-order bias.

For the current joint task, the idle reward is:

```text
event * (mu2 * final_information / Psi - mu1 * missed_event)
    - sensing_penalty * planned_awake_count / N
```

This explicitly extends the original Eq. (24) reward. The older reward mode remains available in the base configuration.

The wake-stage event reward retains the Eq. (25) form:

```text
mu2 * final_information - executed_request_count / N
```

The recommended RL wake table receives incremental credit: information gained by each executed request minus that request's cost. Its wake discount is zero. This helps assign credit to the individual requests that produced useful information.

Wake actions are selected together after the initial reports, then executed in their initial ranking order. The learned RL/DT wake vector is not recalculated after every additional report. This differs from the adaptive sequential baseline heuristic.

**Main parameters:** `cfg.rl.episodes`, `steps`, `learning_rate`, `discount`, `epsilon_start/end`, `mu1`, `mu2`, and validation controls.

### Decision Transformer — dt

The DT learns from saved examples of decisions and outcomes. In easy words: RL produces experience, and the DT learns which actions tend to appear in useful histories.

There are two independent transformer networks:

- `policy.dt.idle` predicts the awake/sleep vector.
- `policy.dt.wake` predicts the extra-report request vector.

The full pipeline is:

1. **Obtain an RL teacher.** Reuse the frozen RL policy for the same deployment, or train a teacher if none was supplied.
2. **Collect offline episodes.** Run frozen copies of that teacher with exploration. The tables are not updated during collection. Optional baseline episodes can be added; the bundled joint calibration uses zero.
3. **Hold out a whole episode.** Training windows and validation windows come from different episodes.
4. **Build sequence inputs.** Compute offline return-to-go targets and shift actions/rewards so the current action label is not given as input.
5. **Train both networks.** Use masked binary cross-entropy, full backpropagation, Adam, and held-out-loss checks.
6. **Select the deployment policy.** Test frozen checkpoint pairs and wake thresholds on separate closed-loop validation rollouts using the information/miss score.
7. **Freeze everything for final testing.** No learning occurs on the final test stream.

Each decision token contains:

```text
[current observed state,
 previous action vector,
 previous observable reward,
 desired normalized return-to-go,
 stage identifier]
```

The state has eight features per sensor. The complete input has `9*N + 3` components, and the network predicts `N` binary actions. Attention looks across past decision instants, not across a sequence of individual sensor tokens. The idle history advances every slot; the wake history advances only at eligible extra-report decisions.

**Return-to-go** means a discounted total of rewards from a decision onward. Offline training can compute it from a completed recorded trajectory. At test time, the requested return starts from a percentile of training returns and is updated using observed feedback. The DT does not receive the actual future test rewards.

Causal masking prevents a prediction from seeing later tokens. Online feedback excludes hidden missed-event labels: a base station cannot know that an entirely unreported event occurred. Such labels can still define offline simulation rewards and evaluation metrics.

The recommended network has trainable attention, layer normalization, residual connections, and feed-forward layers. All parameter families are trained; this is not just a fixed feature extractor.

The models are deployment- and device-count-specific. The experiment trains fresh policies for each deployment; it does not claim transfer to arbitrary sensor positions or another N.

**Main parameters:** `cfg.dt.data_episodes`, `data_steps`, `context`, `d_model`, `heads`, `blocks`, `ff_size`, `updates`, `batch_size`, `learning_rate`, desired return, and validation controls.

### Shared coordination in the recommended RL/DT setup

The selected RL/DT scores pass through `coverage_rank` coordination. A fixed grid represents the known monitored area. The controller greedily chooses an energy-eligible awake set that covers it, combining coverage gain with learned scores and estimated battery energy.

`configure_learning_control.m` defines the awake budget/constraints; `learning_idle_actions.m` chooses the awake set. The optional mean-harvest cap further limits the awake budget. The selected 20 m calibration disables that optional cap, while retaining energy guards and actual battery constraints.

These are designed control rules shared by RL and DT, not weights learned by the transformer or Q tables. The recommended methods should be understood as learned scores combined with documented spatial/energy coordination.

## 5. Your example: will it give the best RL and DT results?

**It runs the bundled, selected quick configuration for the 20 m model. It does not guarantee the best possible RL/DT performance or exact paper results.**

With the bundled calibration present, these values in your example already match the selected settings:

| Control | Selected quick value |
| --- | --- |
| RL episodes / slots per episode | 8 / 1600 |
| RL learning rate / mu1 / mu2 | 0.01 / 5 / 5 |
| RL checkpoint validation | 2400 slots, one stream per check |
| DT offline episodes / slots per episode | 6 / 1600 |
| DT context / maximum updates per stage | 16 / 200 |
| DT learning rate | 0.001 |
| DT width / heads / feed-forward width | 16 / 2 / 32 |
| Joint missed-event weight | 1 |

Early stopping can finish training before the configured maximum. One offline episode is held out, so six collected DT episodes do not mean six training episodes.

Other influential settings are inherited from the calibration, including coverage coordination, energy margin, the teacher/exploration controls, class balancing, and DT closed-loop selection. The wake threshold in `cfg.dt.wake_threshold` is a selection candidate; the final selected threshold is stored in `policy.dt.wake.action_threshold`.

The quick calibration compared **three RL candidates and two DT architectures**, using the mean joint validation score across N=50 and N=250. It selected the RL settings first, then compared DT architectures using that selected RL teacher. The selected settings are best among those tested at each step for that score. They are not proven optimal, are not necessarily best at each individual N, and were not selected for N=10.

The selection score is:

```text
J = information_per_actual_event / Psi
    - cfg.objective.miss_weight * missed_event_fraction
```

A larger score is preferred. The selected candidate can sacrifice some information to avoid more misses. There is no unique “best for both metrics” without specifying that tradeoff.

The final bundled three-deployment tests also do not show universal superiority: the cluster baseline beats the learned methods on both metrics at N=250 in the 20 m model. Detailed means, uncertainty, and comparisons are in `JOINT_TUNING_RESULTS.md`.

### Ready-to-run version of your script

Run this from the extracted `EH_IoT_clean` folder:

```matlab
clear; clc; close all;

% Select the physical model explicitly.
% 'paper':                 20 x 20 m, Bernoulli harvesting
% 'archive_compatibility': 10 x 10 m, uniform harvesting
cfg = recommended_information_detection_config('paper');

% Include RL before DT so DT can reuse the frozen RL teacher.
cfg.methods = {'random','cluster','rl','dt','genie'};

% FINAL TEST budget. These settings do not enlarge training.
cfg.N_values = [10 50 250];
cfg.MCarlo = 3;
cfg.total = 10000;

% RL TRAINING budget and reward.
cfg.rl.episodes = 8;
cfg.rl.steps = 1600;
cfg.rl.learning_rate = 0.01;
cfg.rl.mu1 = 5;
cfg.rl.mu2 = 5;

% DT OFFLINE DATA and TRAINING.
cfg.dt.data_episodes = 6;
cfg.dt.data_steps = 1600;
cfg.dt.context = 16;
cfg.dt.updates = 200;
cfg.dt.learning_rate = 0.001;

% Validation preference, separate from the RL reward coefficients.
cfg.objective.miss_weight = 1;

% Use a new folder for a different experiment.
cfg.output_dir = fullfile(pwd,'output_my_experiment');

% Check the effective settings after all overrides.
disp(cfg.rl);
disp(cfg.dt);
disp(cfg.objective);

Results = run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);
```

This loads settings, trains fresh models, selects checkpoints on validation data, then evaluates frozen policies. It does not automatically launch the hyperparameter search or load a previously saved trained policy.

### What to do if you want a stronger experiment

For a first run, use the script above unchanged. For a more serious search, use the larger validation-based calibration:

```matlab
% Run from EH_IoT_clean. This can take substantial time.
calibration = tune_information_detection('paper','extended');

% Load the settings selected by that new calibration.
cfg = recommended_information_detection_config('paper');
cfg.methods = {'random','cluster','rl','dt','genie'};
cfg.N_values = [10 50 250];
cfg.MCarlo = 25;
cfg.total = 10000;
cfg.output_dir = fullfile(pwd,'output_extended_final');

Results = run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);
```

The extended search increases training, data, updates, and validation budgets. It still uses a finite candidate grid; it does not guarantee an improvement. This larger experiment was not executed as part of the delivered quick calibration.

The tuner writes to `output_joint_calibration_paper`. Preserve that folder first if you want to keep the bundled calibration unchanged.

For a broader search, edit `grid` and `architectures` in `tune_information_detection.m`. Edit its `counts` if you need selection over particular sensor counts; the extended default uses N=[10 100 250]. At each N, the outer search currently uses one calibration deployment with multiple independent event/harvest streams. More calibration deployments would be needed for a stronger geometry-generalization assessment.

If reliability matters more, increase `miss_weight` in the tuner's `base.objective` before candidate evaluation and consider more miss penalties in its RL grid. Changing `cfg.objective.miss_weight` only in the final-run script changes checkpoint selection for that run, but does not rerun the saved architecture/hyperparameter search.

Use independent validation to compare changes, then run final tests after choosing the settings. A lower DT imitation loss alone does not prove higher information or fewer misses. More episodes, data, network width, or updates can help, have no effect, or worsen generalization; verify the actual closed-loop metrics.

Increase `MCarlo` to assess variation across independent deployments. Increasing only `total` gives a longer final test; it does not give the learner additional training. Three deployments have limited statistical precision.

## 6. Where to configure parameters

The configuration layers, from base settings to effective settings, are:

1. `paper_config`: base physics and controls.
2. `tuned_config` and `recommended_config`: information-oriented defaults and any earlier calibration.
3. `information_detection_config`: current joint-task defaults.
4. `recommended_information_detection_config`: current joint calibration and budget choice.
5. Your script's final `cfg` overrides.
6. `run_experiments(cfg)`: consumes the effective settings.

The recommended loaders can read `selected_cfg` from calibration MAT files. Therefore, editing `paper_config.m` alone may not change the final values when a saved configuration overrides it.

**For one experiment, put your overrides after the recommended loader and before `run_experiments(cfg)`. Put them after any other assignments to the same fields.**

| What you want to change | Field or file |
| --- | --- |
| Monitored area | `cfg.A`, `cfg.B` |
| Event probability | `cfg.alpha` |
| Harvest model/rate/quantum | `cfg.harvest_model`, `cfg.lambda`, `cfg.E_B`, `cfg.TTI` |
| Battery capacity and initial charge | `cfg.E_max`, `cfg.initial_battery` |
| Idle, transmission, sleep/WuR costs | `cfg.idle_E`, `cfg.Tx_E`, `cfg.wake_up_Energy` |
| Sensing range and information decay/scale | `cfg.active_distance`, `cfg.eta`, `cfg.Psi` |
| Detection and aggregation assumptions | `cfg.detection_model`, `cfg.aggregation` |
| Placement | `cfg.deployment` |
| Methods, device counts, repetitions, test slots | `cfg.methods`, `cfg.N_values`, `cfg.MCarlo`, `cfg.total` |
| RL exploration and learning | `cfg.rl.epsilon_start/end`, `learning_rate`, `discount` |
| RL information/miss reward | `cfg.rl.mu1`, `mu2`, `sensing_penalty`, `reward_mode` |
| RL training and checkpoint selection | `cfg.rl.episodes`, `steps`, `validation_every`, `validation_steps`, `validation_trials`, `patience` |
| DT offline data and teacher | `cfg.dt.data_episodes`, `data_steps`, `data_epsilon_start/end`, `reuse_rl_teacher` |
| DT architecture | `cfg.dt.context`, `d_model`, `heads`, `blocks`, `ff_size`; width must be divisible by head count |
| DT optimization | `cfg.dt.updates`, `batch_size`, `learning_rate`, `gradient_clip`, `patience` |
| DT return conditioning | `cfg.dt.desired_return_quantile` |
| DT task-level selection | `cfg.dt.rollout_selection`, `rollout_validation_steps`, `rollout_validation_trials`, `wake_threshold` |
| RL/DT awake coordination | `cfg.rl` / `cfg.dt` fields `action_mode`, `cluster_scale`, `coverage_grid`, `learned_weight`, `energy_weight` |
| RL/DT energy restrictions | `energy_guard`, `energy_margin`, `cap_groups_to_energy` under each method |
| Tradeoff used to select checkpoints/candidates | `cfg.objective.miss_weight` |
| Reproducibility and output | `cfg.seed`, `cfg.output_dir`, `cfg.resume`, `cfg.figure_formats` |

**Reward versus selection:** `mu1` and `mu2` change what RL learns from experience. `miss_weight` changes how validation ranks policies. They have different jobs; raising one does not automatically change the other.

Changing physical parameters changes the scientific experiment. Changing area or harvesting to reach a published information value is not simply “better tuning.”

### The physical profiles are different

| Profile | Area | Harvesting | Other distinctions |
| --- | --- | --- | --- |
| Recommended `'paper'` | 20 x 20 m | Fixed-quantum Bernoulli arrivals | Journal-model reconstruction; max aggregation, range 4 m, WuR cost 1/14 |
| Recommended `'archive_compatibility'` | 10 x 10 m | Uniform [0,E_B] every slot | Retains journal range, costs, and max aggregation |
| `paper_config('archive')` | 10 x 10 m | Uniform [0,E_B] every slot | Conference-like corrected model: range 5 m, WuR cost 1/20, uncapped sum |

The latter two are not interchangeable. For the Bernoulli model, arrival probability is `1-exp(-lambda*TTI)`. The uniform model does not use `lambda` to thin arrivals.

The normalized `E_B=1` and `TTI=1` are reconstruction assumptions; the main paper's baseline reporting does not completely resolve these quantities. See `MODEL_NOTES.md`.

### 6.1 Exactly where 'paper' and 'archive_compatibility' are defined

Open `tuned_config.m` and search for `switch model` or `case 'archive_compatibility'`. The physical-profile selection is:

```matlab
cfg = paper_config('quick');

switch model
    case 'paper'
        % Keep the physical defaults from paper_config.m.
    case 'archive_compatibility'
        cfg.A = 10;
        cfg.B = 10;
        cfg.harvest_model = 'uniform';
end
```

This is an excerpt, not a complete experiment script. Open `paper_config.m` to see the base assignments, including the following bundled values:

| Physical field | Recommended 'paper' | Recommended 'archive_compatibility' |
| --- | --- | --- |
| `cfg.A`, `cfg.B` | 20, 20 m | 10, 10 m |
| `cfg.alpha` | 0.1 | 0.1 |
| `cfg.harvest_model` | `'bernoulli_fixed'` | `'uniform'` |
| `cfg.lambda` | 0.1 | Retained as 0.1, but unused by uniform harvesting |
| `cfg.E_B` | 1 | 1 |
| `cfg.TTI` | 1 | 1 |
| `cfg.E_max` | 100 | 100 |
| `cfg.initial_battery` | 100 | 100 |
| `cfg.idle_E` | 1 | 1 |
| `cfg.Tx_E` | 10 | 10 |
| `cfg.wake_up_Energy` | 1/14 | 1/14 |
| `cfg.active_distance` | 4 m | 4 m |
| `cfg.eta`, `cfg.Psi` | 1, 1 | 1, 1 |
| `cfg.detection_model` | `'range'` | `'range'` |
| `cfg.aggregation` | `'max'` | `'max'` |
| `cfg.deployment` | `'uniform'` | `'uniform'` |

These are the bundled profile values, not values that must remain fixed in every experiment. The final loaded `cfg` is authoritative if you edit or recalibrate the project.

For `'paper'`, mean harvested energy per device per slot is `E_B*(1-exp(-lambda*TTI))`, approximately 0.09516 at the defaults. For `'archive_compatibility'`, it is `E_B/2=0.5`. At the same N, the 10 m profile is also four times as dense. A result difference between profiles therefore includes different physical conditions.

The recommended loader also reads profile-specific learning calibration. Consequently, the selected RL/DT settings can differ between profiles: for example, the bundled paper DT has width 16 with 2 heads, whereas the archive-compatible DT has width 32 with 4 heads.

Three similar-looking calls have different meanings:

| Call | Meaning |
| --- | --- |
| `recommended_information_detection_config('paper','quick')` | The journal-model reconstruction with the selected quick learning settings. |
| `recommended_information_detection_config('paper','paper_budget')` | The same physical model with the large training/evaluation budget. |
| `paper_config('paper')` | Base configuration with the large budget and the baseline method list; not the current recommended RL/DT loader. |

`paper_config('archive')` is a separate conference-like profile. It is not the same as recommended `'archive_compatibility'`. Use the exact supported names, including lowercase letters.

### 6.2 Print and compare the actual values before running

Run the following in the MATLAB Command Window from `EH_IoT_clean`. It loads settings but does not train or simulate:

```matlab
cfg_paper = recommended_information_detection_config('paper');
cfg_archive = recommended_information_detection_config('archive_compatibility');

disp('PAPER: effective configuration');
disp(cfg_paper);
disp(cfg_paper.rl);
disp(cfg_paper.dt);
disp(cfg_paper.objective);

disp('ARCHIVE COMPATIBILITY: effective configuration');
disp(cfg_archive);
disp(cfg_archive.rl);
disp(cfg_archive.dt);
disp(cfg_archive.objective);
```

For an individual value, use its field name:

```matlab
cfg_paper.A
cfg_paper.harvest_model
cfg_paper.rl.mu1
cfg_paper.dt.d_model
```

For your own experiment, print `cfg` after your last assignment and immediately before `run_experiments(cfg)`. After the run, `Results.cfg` records the settings actually used. Inspect `Results.cfg` when opening an existing result file; a newly loaded default configuration does not describe an older result automatically.

### 6.3 Apply changes in your own experiment script

For most experiments, leave the helper functions unchanged. Create `run_my_experiment.m` in `EH_IoT_clean`, load a configuration once, apply your changes, then call the shared runner directly.

This complete example demonstrates modifications to event probability, battery capacity, training budgets, and the reliability preference. These illustrative values have not been selected by the bundled calibration and are not a claim of better performance.

```matlab
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));

% Load first; override values afterwards.
cfg = recommended_information_detection_config('paper');
cfg.methods = {'random','cluster','rl','dt','genie'};

% Physical changes for this experiment.
cfg.alpha = 0.2;
cfg.E_max = 150;
cfg.initial_battery = 150;

% Final evaluation budget.
cfg.N_values = [10 50 250];
cfg.MCarlo = 3;
cfg.total = 10000;

% RL training changes.
cfg.rl.episodes = 50;
cfg.rl.steps = 1600;
cfg.rl.mu1 = 10;
cfg.rl.mu2 = 5;

% DT data/training changes.
cfg.dt.data_episodes = 12;
cfg.dt.data_steps = 1600;
cfg.dt.updates = 500;

% More weight on missed events during checkpoint selection.
cfg.objective.miss_weight = 2;

% A new experiment gets a new output folder.
cfg.output_dir = fullfile(pwd,'output_custom_alpha02_battery150');
cfg.resume = false;
cfg.figure_visible = 'on';

disp(cfg);
disp(cfg.rl);
disp(cfg.dt);
disp(cfg.objective);

Results = run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);

% Optional broader figures:
% plot_results(Results);
% plot_system_model(Results);
```

Run `run_my_experiment`. Do not configure variables in the Command Window and then call `run_rl_dt` or `main_full` expecting those variables to be preserved: these entry scripts start with `clear` and create their own `cfg`.

To evaluate a longer training budget without changing the physics, keep the original physical fields and modify only the training/validation fields. To test a different physical model, change its fields explicitly, use an appropriate experiment label/output folder, and train new deployment-specific policies.

### 6.4 Change defaults or run another calibration

There are three levels of modification:

| Your goal | What to modify |
| --- | --- |
| Change one experiment | Final `cfg` overrides in your own run script. This is the usual approach. |
| Change source defaults | `paper_config.m` for base physics; `information_detection_config.m` for joint-task defaults; `tuned_config.m` for its profile branch. Saved calibrations can still override these assignments. |
| Search for new settings | `tune_information_detection.m`, followed by a fresh independent final test. |

The current recommended loader first constructs defaults, then replaces the configuration with `calibration.selected_cfg` when `output_joint_calibration_MODEL/calibration.mat` exists. Its default-building path can also read the earlier `output_calibration_MODEL` calibration. Removing just the joint MAT file therefore does not necessarily expose every edited base default.

You do not need to edit calibration MAT files by hand or remove them to run a custom experiment. Final script overrides are explicit and preserve the measured reference.

For the built-in larger search, preserve the existing calibration folder first, then use:

```matlab
calibration = tune_information_detection('paper','extended');
cfg = recommended_information_detection_config('paper');

% Set final evaluation/output controls after loading the selected settings.
cfg.N_values = [10 50 250];
cfg.MCarlo = 25;
cfg.total = 10000;
cfg.output_dir = fullfile(pwd,'output_extended_final');
cfg.resume = false;

Results = run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);
```

Do not copy the old 8-episode / 200-update overrides below this loader if your intention is to keep the new larger training budget.

To modify what the search itself tests, edit these variables in `tune_information_detection.m`:

| Search variable | Meaning |
| --- | --- |
| `grid` | RL rows: group scale, energy margin, mu1, mu2, learned-score weight, energy weight, mean-EH cap. |
| `architectures` | DT rows: embedding width, context, heads, feed-forward width, learning rate, wake threshold, return quantile. |
| `counts` | Device counts used for outer candidate selection. |
| `K`, `repetitions` | Outer validation slots and independent event/harvest streams. |
| `base.rl.*` | Training and internal RL checkpoint-validation budget. |
| `base.dt.*` | Offline data, DT training, and closed-loop selection budget. |
| `base.objective.miss_weight` | Reliability preference used by the search. |
| `base.A`, `base.alpha`, and other physical fields | Physical conditions used during a custom search. |

The search creates its own `base` configuration. Modifying `cfg` in a separate run script does not modify that search configuration. Place any custom `base` overrides after its quick/extended budget-selection block and before candidate construction/evaluation.

For a custom objective or physical model, make a separate copy of the tuner with a matching new function/file name and a distinct output `folder`. This preserves the built-in reference calibration. Use the returned selected configuration directly, because the standard recommended loader only reads its model-named calibration directory:

```matlab
% After your custom tuner has returned "calibration":
cfg = calibration.selected_cfg;

% The tuning base disables output/plot controls; restore them for final tests.
cfg.save_results = true;
cfg.save_learning_models = true;
cfg.make_plots = true;
cfg.capture_trace = true;
cfg.verbose = true;
cfg.dt.observable_feedback = true;

cfg.methods = {'random','cluster','rl','dt','genie'};
cfg.N_values = [10 50 250];
cfg.MCarlo = 25;
cfg.total = 10000;
cfg.resume = false;
cfg.output_dir = fullfile(pwd,'output_custom_calibration_final');

Results = run_experiments(cfg);
plot_information_detection(Results);
plot_learning(Results);
```

Choose candidates using independent validation, then evaluate the chosen settings on final test streams. Changing physics or the task preference can invalidate the relevance of the old calibration; a larger budget alone does not guarantee an improvement.

### 6.5 Sweep a parameter and keep separate results

For a sweep, start from one selected configuration and create a fresh copy for each parameter value. The following is a complete event-probability sweep; each point trains new policies and can take time.

```matlab
clear; clc; close all;
base = recommended_information_detection_config('paper');
base.methods = {'random','cluster','rl','dt','genie'};
base.N_values = [10 50 250];
base.MCarlo = 3;
base.total = 10000;

alphas = [0.05 0.1 0.2];
series = cell(size(alphas));

for k = 1:numel(alphas)
    cfg = base;
    cfg.alpha = alphas(k);
    cfg.resume = false;
    cfg.output_dir = fullfile(pwd, ...
        sprintf('output_alpha_%03d',round(100*alphas(k))));

    series{k} = run_experiments(cfg);
    plot_information_detection(series{k});
end
```

Keep the same N list, method list, and seed for a controlled comparison. The simulator reuses corresponding random inputs where the changed model permits; an increased event probability intentionally changes which slots contain events. This example studies policies retrained for each condition, not one fixed policy transferred to new conditions.

### 6.6 Settings that need to be changed together

- **Capacity and initial charge:** require `0 <= initial_battery <= E_max` for a numeric initial charge. If you reduce capacity below 100, also reduce the default initial charge, or use `cfg.initial_battery='uniform'`.
- **DT width and heads:** require `mod(d_model,heads)==0`. For example, width 32 with 4 heads is valid. Adjust `ff_size` intentionally when changing network capacity.
- **DT episode count:** use at least three offline episodes. The wake stage also needs actual training and held-out wake decisions; sparse detections may require longer/more collection episodes.
- **RL and DT coordination:** if you want the same designed awake-set constraints, set both methods' controls explicitly. Changing an RL field after the loader does not automatically update the corresponding DT field.
- **Training and validation budgets:** if you increase training substantially, consider `cfg.rl.validation_steps/trials` and `cfg.dt.rollout_validation_steps/trials` as well. A long final test does not strengthen short checkpoint validation.
- **Harvesting law:** `lambda` affects `'bernoulli_fixed'`, but not `'uniform'` harvesting. `E_B` scales the harvest in both modes.
- **Objective and reward:** `cfg.rl.mu1/mu2` change training rewards; `cfg.objective.miss_weight` changes task selection. For a new hyperparameter search, change its `base` preference too.
- **Saved checkpoints:** changed physics, training, N, or repetitions need a new output directory. Resume only an unchanged compatible experiment.

For example, to preserve matching coordination after changing RL controls, put this after those changes:

```matlab
cfg.dt.action_mode = cfg.rl.action_mode;
cfg.dt.cluster_scale = cfg.rl.cluster_scale;
cfg.dt.energy_guard = cfg.rl.energy_guard;
cfg.dt.energy_margin = cfg.rl.energy_margin;
cfg.dt.cap_groups_to_energy = cfg.rl.cap_groups_to_energy;
cfg.dt.coverage_grid = cfg.rl.coverage_grid;
cfg.dt.learned_weight = cfg.rl.learned_weight;
cfg.dt.energy_weight = cfg.rl.energy_weight;
```

Matching is a design choice, not a requirement of the code. Keep the two sets different if that is the experiment you intend to study.

### 6.7 Check that a modification was actually applied

If values seem unchanged, check the following:

1. Print `cfg` after the last assignment, then inspect `Results.cfg` after execution.
2. Check that you edited the script you actually ran. A later loader call or field assignment replaces earlier changes.
3. Check that MATLAB is resolving functions from the intended extracted folder:

```matlab
pwd
which recommended_information_detection_config -all
which paper_config -all
which tuned_config -all
```

4. Inspect the new `cfg.output_dir`, not an older results folder. By default, plots are saved with invisible figures; set `cfg.figure_visible='on'` to display them too.
5. If a compatible run was resumed, completed deployments are reused; they are not retrained. Use a new output directory for a new experiment.
6. Remember that `cfg.dt.wake_threshold` is a validation candidate. The selected policy can use another tested threshold. To inspect one saved DT policy from an experiment containing N=50:

```matlab
saved = load(fullfile(cfg.output_dir,'models','dt_N50_trial1.mat'));
disp(saved.policy.dt.wake.action_threshold);
disp(saved.policy.dt_selection);
```

The original per-method explanations and the complete file map below remain applicable to these custom experiments.



## 7. File-by-file map

You normally edit the entry script or final `cfg` values. The tables below explain the rest of the project so you can follow the execution without reading every mathematical helper first.

### Experiment and configuration files

| File | Purpose |
| --- | --- |
| `main_full.m` | Baseline entry point and broad plots. |
| `run_rl_dt.m` | Current joint-task RL/DT entry point with training plots. |
| `run_information_detection_experiment.m` | Current focused information/miss comparison. |
| `run_paper.m` | Baseline entry point with the large Monte Carlo budget. |
| `Benchmark_scenario.m` | Random-only wrapper. |
| `scenario_main_code.m` | Adjusted-only wrapper. |
| `scenario_kmeans.m` | Cluster-only wrapper. |
| `genie_aided_scenario.m` | Genie-only wrapper. |
| `run_sensitivity.m` | Event-probability sweep. |
| `paper_config.m` | Base physical parameters, baseline controls, and original learning defaults. |
| `tuned_config.m` | Earlier information-oriented learning defaults and explicit model choice. |
| `recommended_config.m` | Loads earlier information-only calibrated settings when present. |
| `information_detection_config.m` | Adds the current joint objective, coverage rules, observable feedback, and training defaults. |
| `recommended_information_detection_config.m` | Loads the current joint calibration, applies the requested budget, and sets portable output controls. |
| `validate_config.m` | Checks that the supplied configuration is valid before running. |
| `run_experiments.m` | Loops over N and deployments, creates common test scenarios, builds/trains policies, evaluates, and saves statistics/models. |
| `build_policy.m` | Creates schedules, selects adjusted schedules, or invokes RL/DT training for the requested method. |

### Shared physical model and geometry

| File | Purpose |
| --- | --- |
| `make_scenario.m` | Generates positions, events, initial batteries, and harvest samples from a seed. |
| `simulate_network.m` | Executes every slot, battery costs, reports, requests, rewards, Q updates during training, and metrics. |
| `PPP.m` | Places exactly N sensors uniformly. The retained name does not mean it draws a Poisson-distributed N. |
| `GridDeployment.m` | Creates a centered grid deployment. |
| `EH_random.m` | Standalone energy-harvest sampler; the main scenario generator creates its shared harvest arrays directly. |
| `check_idle.m` | Converts the advancing slot index and schedule into energy-feasible awake states. |
| `check_active.m` | Checks sensing range, optional probabilistic detection, and report information. |
| `update_battery_active.m` | Applies transmission cost/success and depleted-attempt behavior. |
| `update_battery_harvest.m` | Applies costs, end-slot harvesting, finite-capacity clipping, and actual energy accounting. |
| `aggregate_information.m` | Combines report strengths using max, saturated sum, or uncapped sum. |
| `kmeans_cluster.m` | Toolbox-free spatial grouping and within-group round-robin schedule. |
| `voronoi_information_target.m` | Clips Voronoi cells to the monitored rectangle and derives the geometric information target. |
| `correlation_lookup.m` | Precomputes expected sensing scores from report strengths and inter-sensor distances, averaging unknown event bearing. |
| `wake_close_device.m` | Ranks eligible sleeping sensors from received reports; does not use the true event location. |
| `battery_transition_matrix.m` | Separate stochastic battery-chain helper for a fixed action mixture. |
| `Markov_battery_probability.m` | Standalone example of that battery chain; not the full adaptive RL/DT network chain. |

### RL and shared learning controls

| File | Purpose |
| --- | --- |
| `train_two_stage_rl.m` | Trains and validates the two shared Q tables; returns the best frozen checkpoint. |
| `q_state.m` | Maps estimated/history features into finite Q-table state indices. |
| `shared_q_update.m` | Applies averaged simultaneous TD updates to shared table cells. |
| `learning_observation.m` | Builds eight observable/history features per sensor for the sequence models. |
| `idle_task_reward.m` | Defines the original idle reward or the current information/miss reward. |
| `validation_objective.m` | Routes RL checkpoint evaluation to the configured validation score. |
| `information_detection_objective.m` | Computes normalized information minus weighted missed-event fraction. |
| `configure_learning_control.m` | Builds RL/DT spatial coordination, awake-budget, and estimated-energy constraints. |
| `learning_idle_actions.m` | Converts learned scores into a coordinated awake set. |
| `train_q_reference.m` | Trains the earlier one-stage shared-Q reference. |

### Decision Transformer

| File | Purpose in easy words |
| --- | --- |
| `train_decision_transformer.m` | Organizes teacher training/reuse, offline collection, whole-episode split, both networks, and task selection. |
| `dt_prepare_trajectory.m` | Builds return targets and correctly shifted previous-action/reward inputs. |
| `dt_sequence_window.m` | Extracts a recent context and masks left padding/unavailable actions. |
| `dt_initialize.m` | Creates all trainable transformer parameters. |
| `dt_forward.m` | Runs causal attention, normalization, feed-forward layers, and action logits. |
| `dt_loss_gradient.m` | Computes masked binary action loss and gradients for every parameter family. |
| `dt_adam_update.m` | Updates parameters with Adam and gradient clipping. |
| `train_dt_stage.m` | Trains one stage from offline windows and records held-out losses/checkpoints. |
| `select_dt_rollout_checkpoint.m` | Chooses frozen idle/wake checkpoint pairs and wake thresholds using separate simulated validation outcomes. |
| `dt_control.m` | Uses a trained network to choose actions from current/past observations. |
| `dt_feedback.m` | Stores observable feedback and updates the desired return for the next decision. |

### Tuning, comparison, and audit helpers

| File | Purpose |
| --- | --- |
| `tune_information_detection.m` | Current finite candidate search for the joint information/miss objective. |
| `pareto_information_detection.m` | Identifies candidates not dominated on both information and missed events. |
| `compare_joint_tuning.m` | Makes a paired first-deployment comparison with the earlier information-only run. |
| `combine_joint_test_cases.m` | Joins count-specific runs without changing their observations. |
| `plot_joint_profile_comparison.m` | Plots the two physical profiles in separate panels. |
| `tune_rl_dt.m` | Earlier information-only hyperparameter search. |
| `focus_information_calibration.m` | Re-scores recorded candidates for the earlier information-only selection. |
| `run_tuned_comparison.m` | Earlier search-and-test workflow. |
| `run_information_experiment.m` | Earlier information-only entry point. |
| `combine_information_test_cases.m` | Joins earlier count-specific information tests. |
| `plot_information_focus.m` | Compares earlier information results under separately labeled profiles. |
| `audit_physical_model.m` | Computes algorithm-independent information/energy limits. |
| `run_reproduction_audit.m` | Entry point for the physical audit. |
| `rerun_before_reference.m` | Replays the archived earlier implementation for paired auditing; use a fresh session as instructed in that file. |

### Results, plots, and checks

| File | Purpose |
| --- | --- |
| `metric_names.m` | Lists the scalar measurements saved per independent deployment. |
| `mean_ci95.m` | Computes means and Student-t 95% intervals across deployment means. |
| `write_results_csv.m` | Exports summary statistics and raw deployment measurements. |
| `ensure_output_directory.m` | Creates output directories robustly, including split-run shared-parent creation. |
| `plot_results.m` | Produces the broader information, energy, miss, and battery plots. |
| `plot_information_detection.m` | Produces the current information/miss plots and focused CSV. |
| `plot_information_curve.m` | Produces an information-only plot and exports both information normalizations. |
| `plot_learning.m` | Plots actual RL rewards and DT train/validation losses. |
| `plot_system_model.m` | Shows an example deployment, cells, battery trace, and states. |
| `plot_energy_budget.m` | Shows analytical harvest/fixed-use comparisons, not freshly simulated EH sweeps. |
| `save_figure.m` | Exports figures using configured formats. |
| `run_validation.m` | Checks schedules, sensing, batteries, seeds, energy balance, and limiting cases. |
| `validate_learning.m` | Checks learning integration and frozen inference. |
| `validate_transformer.m` | Checks full gradients, causal masking, shifted inputs, and learning. |
| `validate_tuning.m` | Checks coordination, energy guards, and balanced DT training. |
| `validate_information_detection.m` | Checks the joint objective, Pareto rule, coverage, teacher reuse, selection, and hidden-miss invariance. |

### Other documentation

| File | Read it for |
| --- | --- |
| `README.md` | This full project guide. |
| `LEARNING_GUIDE.md` | Additional RL/DT architecture details and saved-model reuse. |
| `JOINT_TUNING_GUIDE.md` | Current objective and tuning design. |
| `JOINT_TUNING_RESULTS.md` | Actual joint calibration/test outcomes, uncertainty, and limitations. |
| `MODEL_NOTES.md` | Paper/source differences and physical assumptions. |
| `VALIDATION.md` | Checks actually executed for the delivered build. |
| `TUNING_GUIDE.md`, `TUNING_RESULTS.md` | Historical information-only tuning and results. |
| `LICENSE` | The preserved MIT license and attribution. |

## 8. Where results and trained models are saved

`cfg.output_dir` controls new outputs. Typical files are:

| File or folder | Contents |
| --- | --- |
| `results.mat` | `Results`, including effective configuration, raw samples, means, intervals, and example policies. |
| `summary.csv` | Mean results and confidence-interval half-widths by N and method. |
| `samples.csv` | Individual independent-deployment measurements. |
| `information_detection.csv` | Focused information and missed-event results, counts, and both information normalizations. |
| `fig07_information_per_event.png` | Current actual-event information plot. |
| `fig09_misdetection.png` | Current missed-event percentage plot. |
| `rl_training_N*.png`, `dt_training_N*.png` | Training/validation histories from the retained example policies. |
| `models/rl_N*_trial*.mat` | Frozen RL policy and configuration for each deployment. |
| `models/dt_N*_trial*.mat` | Frozen DT policy and configuration for each deployment. |
| `checkpoint.mat` | Completed-deployment checkpoint for resuming a compatible run. |

`plot_results` uses `fig07_information.png` for the expected-event normalization. Figure numbers identify metric families; they do not assert that plotted numbers reproduce the publication.

Useful access from MATLAB:

```matlab
Results.mean.info_per_event    % Rows: methods; columns: Results.N
Results.mean.misdetection      % Fractions, not percentages
Results.ci95.info_per_event    % 95% confidence-interval half-widths
Results.raw.info_per_event    % Deployment x method x N
Results.cfg                   % Effective settings used for this run
Results.labels                % Human-readable method labels
```

`Results.policy{method_index,N_index}` retains the first deployment's policy. Per-trial model files retain the other saved RL/DT policies. To reuse a model on the same deployment, follow the example in `LEARNING_GUIDE.md`; `run_experiments` ordinarily builds/trains fresh policies.

Bundled `output_joint_calibration_*` directories contain settings/search evidence. Bundled `output_joint_test_*` directories contain the executed joint tests. Older `output_*` folders preserve earlier experiments; they are not silently substituted into new simulations.

## 9. Reproducibility, resuming, and validation

Within a deployment, every final-test method receives the same positions, initial charge, event stream, and harvest samples. Training and validation use other deterministic seeds.

Keep the seed, the N list and its order, the method list and its order, and the configuration unchanged when reproducing a run. Seed offsets depend on loop indices, so removing earlier N values or methods can change a learned policy's training seed.

Use a new output directory for changed settings. With `cfg.resume=true`, a compatible `checkpoint.mat` can reuse completed deployments. An interrupted deployment is rerun from its seed; training is not resumed halfway through an episode. Mismatched configurations are rejected.

Optional mechanics checks, run from the project folder:

```matlab
run_validation
validate_learning
validate_transformer
validate_tuning
validate_information_detection
```

These checks validate implementation mechanics, causality, gradients, and physical accounting. They do not establish that a policy is globally optimal or that the publication's curves have been reproduced.

## 10. How to interpret results against the paper

The delivered joint experiment was executed for N=[10 50 250], three independent deployments per N, and 10000 test slots per deployment, for both physical profiles. It is a measured quick study, not the full 250-episode/1000-deployment experiment.

Under the 20 x 20 m, uniform-event, exponential-decay, max-information assumptions, the audited any-placement information bound at N=250 is about 0.6305 even before energy losses. An RL level near 0.72 cannot be reached by tuning the learner alone under those exact assumptions. The 10 m alternate profile changes that physical limit and must remain separately labeled.

Inspect information, missed events, uncertainty, and energy together. DT need not beat its RL teacher, and RL/DT need not beat every heuristic in a particular geometry or training budget. Report adverse outcomes as well as improvements. The code saves measured outcomes without rescaling, forcing a method ordering, or fitting published figure coordinates.

The original inputs remain unchanged. The source archive's MIT license is preserved in `LICENSE`.

