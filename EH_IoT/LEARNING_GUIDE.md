# RL and decision transformer: complete reconstructed implementations

For the current joint information/missed-event task, run `run_rl_dt.m` or
`run_information_detection_experiment.m`. `JOINT_TUNING_GUIDE.md` documents the
coverage decoder, extended idle reward, observable DT feedback, and closed-loop
checkpoint selection. The original Eq. (24) configuration and information-only
calibration remain available as separate, labeled comparisons.

## Run both methods

In MATLAB, open this folder and execute:

```matlab
run_rl_dt
```

The entry point now uses `recommended_information_detection_config('paper')`
and the calibration in `JOINT_TUNING_GUIDE.md`. It compares random duty cycling, spatial clusters,
two-stage RL, decision transformers, and the finite-battery genie. The
adjusted-duty baseline can be added in the script. It trains fresh models,
freezes them, and exports common-stream test results. Default testing uses
10000 TTIs and three deployments per count. The current executed checks are
in `JOINT_TUNING_RESULTS.md`; earlier one-deployment checks are documented
separately in `TUNING_RESULTS.md`. No pretrained model
is required. The older 400-TTI demonstration remains in `output_rl_dt`.

Both implementations run in base MATLAB, with no Deep Learning Toolbox,
Reinforcement Learning Toolbox, Statistics Toolbox, or Python dependency.
GNU Octave 8.4.0 was used to execute the delivered examples and validation.

## What was missing, and what is now supplied

The uploaded ZIP contains earlier heuristic scenarios and an incomplete
`CustomTransformerEncoderLayer.m`. It has no complete journal RL experiment,
DT data generator, training loop, tuned checkpoint, or saved weights.

The first cleaned package included only `q_reference`: a learned duty-cycle
table paired with a greedy wakeup rule. The update supplies `rl` and `dt` as
complete new reconstructions from the paper. The older reference remains
available under its separate name. The new methods are labeled reconstructed
in every comparison plot. They are not recovered author implementations, and
exact reproduction of the original curves is not established.

## Two-stage reinforcement learning

`train_two_stage_rl.m` trains two parameter-sharing Q tables, each 1440 x 2.

| Stage | Decision clock | Binary action | Reward |
|---|---|---|---|
| Duty cycling | Every TTI | Sleep or ON/sense | Eq. (24): 1 - ON_count/N - alpha*mu1*miss |
| Extra reports | A detected event with eligible sleeping neighbors | Do not request or request | Eq. (25): mu2*final_information - request_count/N |

The table gives the original reward mode. The current task mode explicitly
extends the duty reward to `event*(mu2*information/Psi-mu1*miss)-0.02*ON_count/N`.
Miss labels train/select policies offline; they are excluded from online DT
feedback. The joint selection score is `information/Psi-miss_weight*miss`.

The first table learns using one-step discounted TD transitions between TTIs.
The original global-credit variant learns between detected events. The tuned
variant assigns incremental within-event information credit and uses wake
discount zero; see `TUNING_GUIDE.md`. Pending transitions receive a terminal
update without bootstrapping at the end of an episode.

The BS discretizes estimated battery, reported/inferred sensing strength,
received information, active-neighbor count, prior duty state, and density.
Devices share table parameters, and simultaneous TD changes to the same table
cell are averaged to avoid device-order bias. Training uses epsilon-greedy
exploration. Independent validation rollouts select the frozen checkpoint.

At the extra-report stage, the binary actions are chosen jointly from the
initial received reports. Requests selected by the learned vector execute in
initial correlation-score order. The learner is not replaced by the earlier
greedy information-gain rule, and it does not revise that vector using future
outcomes from within the same event. This explicit joint-action reconstruction
matches the binary vector definition in the paper; it is distinct from the
adaptive sequential heuristic.

The misdetection indicator in Eq. (24) is evaluated when an actual event
occurs. The current event position and missed-event indicator are simulation
reward feedback, never input features for selecting an action. Both tables
are unchanged during evaluation. The tuned spatial action projection and
estimated-energy guard remain active during training and evaluation; they
are explicit control constraints rather than learned weights.

## Offline decision-transformer pipeline

`train_decision_transformer.m` runs the complete sequence:

1. Train a two-stage RL behavior policy on separate simulated trajectories,
   or reuse the frozen RL policy already trained for that deployment.
2. Collect independent exploratory rollouts of frozen copies of its tables.
   Optional cluster/random rollouts can diversify duty-cycle examples.
3. Hold out an entire RL rollout before sampling windows. The final rollout
   uses epsilon=0.35 by default to provide varied held-out actions; if it has
   no wake decisions, another nonempty RL rollout is selected. The selected
   index and all rollout seeds are saved. Evaluation uses disjoint seeds.
4. Compute normalized discounted return-to-go from offline rewards and create
   shifted-action/reward tokens. No current action label is included in its
   input token.
5. Train separate idle and wake transformers with Adam and full backpropagation.
6. Select initial checkpoints using held-out episode loss. The joint task
   configuration additionally selects frozen checkpoint pairs and wake
   thresholds on separate closed-loop information/detection rollouts.

Each stage predicts a joint N-device binary vector. Its state has eight
features per device: estimated battery, observed/inferred sensing score,
received information, x, y, active-neighbor fraction, prior duty action, and
density. Before selecting the current action, a token is assembled as:

```text
[current observed state, previous action vector, previous observed reward,
 requested normalized return-to-go, stage identifier]
```

There are `9*N+3` input components and N output logits per token. An N-device
model is specific to that device count/deployment, consistent with the
paper's deployment-specific policy. The DT does not claim variable-N transfer.
Its joint state contains neighbor/network context; temporal attention operates
over decision instants rather than over individual device tokens.

The normalized offline return is
`G_t = (1-gamma) * sum_{u=t} gamma^(u-t) * reward_u`. At evaluation, the initial
desired return is a configured percentile of TRAINING returns (90% in the
original configuration; the selected task value is in the saved config). It is updated using
only observed reward and clipped to the training range. Actual future test
returns are never supplied. Future rewards in an offline conditioning target
are part of return-conditioned sequence learning, not online oracle inputs.
Fresh configurations set `dt.observable_feedback=true`; the previous reward
token excludes unseen missed-event labels. Historical saved configurations
without that flag retain their old interface solely for paired replay.

### Architecture and optimization

| Component | Demonstration setting |
|---|---|
| Context length | 16 decisions |
| Embedding width | 16 |
| Causal attention | 2 heads |
| Transformer blocks | 2 |
| Feed-forward hidden width | 32, ReLU |
| Normalization/residuals | Pre-layer normalization; residual around attention and FFN |
| Position representation | Fixed sinusoidal encoding |
| Action loss | Masked binary cross-entropy; tuned version balances training classes |
| Optimizer | Adam, learning rate 0.001 |
| Gradient clipping | Global norm 1 |
| Early stopping | Held-out loss; minimum relative improvement 0.1% |

Left-padding and future tokens are masked in attention. Padding and unavailable
wake actions are excluded from the loss. Each stage maintains its own
decision history, so wake history advances at detected-event decisions, while
idle history advances at TTIs. Histories reset at rollout boundaries.

`dt_loss_gradient.m` differentiates the input embedding, Q/K/V projections,
attention output projection, both layer norms, feed-forward layers, and output
head. `dt_adam_update.m` updates every parameter family. Attention is trained;
this is not a random attention feature extractor with only an output layer.

The tokenization, two-network stage decomposition, widths, bin edges, and
training loss are documented reconstruction choices. The paper does not give
the complete settings needed to recover its original implementation. In
particular, the code uses standard TD for tables and binary cross-entropy for
binary action models; it does not claim to reproduce the Appendix's mixed
tabular/Adam/RMSE description or missing Bayesian tuning.

## Files to modify

| File | Role |
|---|---|
| `run_rl_dt.m` | Experiment budget and compared methods |
| `paper_config.m` | All RL/DT hyperparameters |
| `information_detection_config.m` | Joint information/miss objective and coverage settings |
| `tune_information_detection.m` | Independent task-level calibration and Pareto table |
| `train_two_stage_rl.m` | Two shared Q tables and validation |
| `learning_observation.m`, `q_state.m` | Observable features and Q-table bins |
| `simulate_network.m` | Physical model, reward feedback, joint wake execution, trajectory logging |
| `train_decision_transformer.m` | Behavior training, offline data generation, split, two DT stages |
| `dt_prepare_trajectory.m`, `dt_sequence_window.m` | Return targets, shifted histories, masked contexts |
| `dt_initialize.m`, `dt_forward.m` | Transformer parameters and causal forward pass |
| `dt_loss_gradient.m`, `dt_adam_update.m` | Complete gradient and optimizer |
| `dt_control.m`, `dt_feedback.m` | Frozen online decisions and desired-return update |
| `train_dt_stage.m` | Minibatches, held-out losses, checkpoint selection |
| `select_dt_rollout_checkpoint.m` | Frozen closed-loop task selection before testing |
| `plot_learning.m` | Actual training rewards and losses |
| `validate_learning.m`, `validate_transformer.m` | Learning and causality checks |

## Reuse a trained model

The example saves `models/rl_N10_trial1.mat`, `models/dt_N10_trial1.mat`, and
corresponding files for other trials/counts. For a new event/EH realization on
the same deployment:

```matlab
saved = load(fullfile('output_joint_test_paper','models','dt_N10_trial1.mat'));
cfg = saved.cfg;
policy = saved.policy;
dev = policy.deployment;
cfg.total = 2000;
cfg.capture_trace = true;
cfg.collect_learning = false;
scenario = make_scenario(cfg,size(dev,1),987654,dev);
[metrics,trace] = simulate_network(cfg,scenario,policy,false);
disp(metrics.info_per_event);
```

The saved policy contains its deployment, train/validation history, and, for
DT, the offline episodes when `cfg.dt.save_dataset=true`. Set that flag false
to omit raw trajectories from exported models. `save_learning_models=false`
disables per-trial model exports. Results still retain the first trial's
policy for each count/method.

## Scale the experiment

Increase the controls explicitly rather than interpreting a short demonstration
as a converged experiment:

```matlab
cfg = recommended_information_detection_config('paper');
cfg.methods = {'random','cluster','rl','dt','genie'};
cfg.N_values = [10 100 250];
cfg.MCarlo = 25; cfg.total = 10000;
cfg.rl.episodes = 250; cfg.rl.steps = 10000;
cfg.rl.validation_steps = 10000;
cfg.dt.data_episodes = 10; cfg.dt.data_steps = 10000;
cfg.dt.updates = 2000; cfg.dt.context = 32;
cfg.dt.save_dataset = false;
cfg.output_dir = fullfile(pwd,'output_learning_large');
Results = run_experiments(cfg);
plot_information_detection(Results); plot_learning(Results);
```

This can be expensive. The full paper's 1000-deployment evaluation can be set
separately, but missing original training settings and the energy-model
discrepancies in `MODEL_NOTES.md` prevent an exact-reproduction claim. Also,
rewards can favor energy-saving/inactive behavior under short training or low
EH. Inspect detection, information, both rewards, and held-out behavior;
training loss alone does not establish a better reporting policy.
