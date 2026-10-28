# Information and missed-event tuning

Run `run_information_detection_experiment.m`. It trains RL and DT from scratch,
evaluates frozen policies on common test scenarios, and exports Fig. 7-style
information and Fig. 9-style missed-event curves. The older information-only
pipeline and its measured results remain available for comparison.

## Explicit selection objective

The joint validation score is

`J = mean_information_per_actual_event / Psi - miss_weight * missed_event_fraction`.

The default `cfg.objective.miss_weight=1` assigns one normalized information
unit to avoiding a missed event. This is an explicit preference, not a value
claimed to be specified by the paper. Increasing it favors reliability more.
Every missed event remains in the information denominator with zero information;
the additional term deliberately gives detection reliability extra weight.
Energy conservation and battery feasibility remain enforced in the simulator.

The search saves both outcomes for every candidate, plus the non-dominated
Pareto candidates. If information and misses conflict, no parameter setting
can be described as simultaneously optimal for both without a stated preference.
Published figure coordinates never enter training, checkpoint selection, or
the hyperparameter score. `mu1` and `mu2` stay in the paper's sensitivity ranges.

## Changes from the information-only controller

1. **Coverage coordination.** Independent shared-Q actions synchronize devices;
   static DT rankings can repeatedly favor a subset of the deployment. The new
   `coverage_rank` decoder greedily covers a fixed 16 x 16 quadrature of the known
   area, subject to the awake-count and estimated-energy constraints. Learned
   Q advantages or DT logits and estimated energy add documented preferences.
   Coverage coordination is shared by both algorithms and is a reconstruction
   design choice, not recovered author code. It does not observe the current
   event, true sleeping-device batteries, or future harvest samples.
2. **Stage-one task reward.** The new optional reward is
   `event * (mu2*information/Psi - mu1*miss) - sensing_penalty*awake/N`.
   It gives the idle-stage learner credit for information as well as detection.
   The event-conditional miss penalty is not multiplied again by alpha. This
   explicitly extends Eq. (24); choose the older configuration to retain that
   equation verbatim. Stage two retains Eq. (25) and incremental request credit.
3. **Offline data quality.** DT can reuse the already trained, frozen RL teacher
   for the same deployment. Its behavior episodes use lower exploration than
   the old 0.60 start. Whole episodes are held out before sampling windows.
   All transformer weights remain trained; this is not a fixed feature model.
4. **Task validation for DT.** BCE is still the imitation training loss. The
   final network pair and wake threshold are selected on separate, closed-loop
   rollouts using delivered information and actual misses. The BCE-best pair
   and two saved checkpoint pairs are candidates. Final tests have different
   seeds and never update or select the models.
5. **Observable feedback.** Simulated missed-event labels can define offline
   rewards/return targets. A BS cannot observe an undetected event. The new DT
   inputs therefore shift only report information and known command costs into
   previous-reward tokens. Online return updates use the same observable
   feedback and remain clipped to training support. Hidden miss labels do not
   leak into future decisions. This is checked directly.

With `cap_groups_to_energy=true`, the spatial awake budget also has an
approximate mean-EH cap. The stated-model search separately tests disabling
that optional cap, because the finite evaluation begins with charged batteries.
Estimated-energy guards and local battery feasibility still apply to every
candidate. The mean BS battery predictor and cap do not prove energy neutrality
or eliminate sample-path battery shortages. Actual batteries gate execution.
Requests are chosen as a joint binary vector after a real report and then
executed in order; this is not adaptive re-planning after every request.

## Physical settings and reproduction limits

`model='paper'` keeps area 20 x 20 m, max-information aggregation, eta=1, range
4 m, and Bernoulli EH. E_B=1 and TTI=1 remain explicit reconstruction assumptions.
`model='archive_compatibility'` changes the area to 10 x 10 m and EH to uniform
[0,1], as in the supplied ZIP, while retaining journal metric/cost/range choices.
This alternate model must not be presented as the Table III setup.

The audited any-placement information upper bound at N=250 in the 20 m model
is about 0.6305, before any energy or sensing-policy loss. The reported RL level
near 0.72 cannot be obtained under those exact geometric assumptions by reward
tuning alone. The supplied archive also lacks complete journal RL/DT code,
training datasets, and original trained weights. Exact reproduction remains
unverified. See `TUNING_RESULTS.md` for the earlier physical audit.

## Run a fresh search or enlarge the budget

```matlab
calibration = tune_information_detection('paper','quick');
cfg = recommended_information_detection_config('paper');
cfg.N_values = [10 50 250];
cfg.MCarlo = 3;
cfg.total = 10000;
Results = run_experiments(cfg);
plot_information_detection(Results);
```

The quick search is a finite grid, not the paper's unavailable Bayesian search.
The bundled calibration used eight RL episodes of 1600 slots, checkpoint
validation of 2400 slots, six offline episodes of 1600 slots, and at most 200
Adam updates per DT stage. Closed-loop DT selection used independent 1600-slot
rollouts. Outer validation used two 10000-slot streams at each of N=50 and 250.
It uses distinct seeds for Q training, Q checkpoint validation, offline episode
holdout, DT rollout selection, outer calibration, and final tests. Calibration
reuses each deployment across candidates because the trained policies are
deployment-specific; held-out test deployments are separate from calibration.
Use `tune_information_detection(model,'extended')` for a larger search, and
`recommended_information_detection_config(model,'paper_budget')` for the large
training/evaluation settings. Neither command claims the unexecuted full
250-episode / 1000-deployment budget has already been run.

`validate_information_detection` checks the objective ranking, Pareto rule,
coverage/energy restrictions, observed-reward token alignment, reused frozen
teacher, selected DT rollout checkpoint, and inference invariance to unseen
missed-event labels. Original gradient/causality tests remain in
`validate_learning` and `validate_transformer`.
