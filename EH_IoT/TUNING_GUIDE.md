# Calibration and remaining reproduction gaps

This guide describes the earlier information-only calibration. For the current
joint information/missed-event task, use `JOINT_TUNING_GUIDE.md` and
`run_information_detection_experiment.m`. The historical measurements remain
in `TUNING_RESULTS.md`; current results are in `JOINT_TUNING_RESULTS.md`.

## Run the improved controller

```matlab
run_rl_dt
```

This entry point now uses `recommended_config('paper')`: measured calibration
settings if they are bundled, or the documented stable settings otherwise.
It retains the stated 20 x 20 m area and reports fresh simulation values.
The default test horizon is 10000 TTIs. Models are trained from scratch.

To rerun the hyperparameter search and then test new streams:

```matlab
run_tuned_comparison
```

Set `model='archive_compatibility'` inside that script to study the source
archive's 10 x 10 m geometry and uniform [0,1] harvest distribution. That is
an explicit alternative physical model, not the journal Table III setting.
Sensing decay, range, costs, and max aggregation still use the journal model.

To evaluate the already selected alternative configuration:

```matlab
cfg = recommended_config('archive_compatibility');
Results = run_experiments(cfg);
plot_results(Results); plot_learning(Results);
```

## What caused the earlier failure

1. **Synchronized Q-table actions.** Many devices shared the same discretized
   state and parameters. Independent greedy binary decisions often made all
   of them ON together. This drained their batteries and did not implement the
   cluster-based sensing setup described in Appendix B.
2. **Uninformative global wake credit.** A request could receive a high team
   reward even if all useful information had arrived before that request.
3. **Checkpoint selection used the wrong goal.** A high energy-saving reward
   could select a policy with little useful reporting. The primary paper goal
   is collected information, Eq. (18).
4. **DT class imbalance.** Most binary labels were sleep/no-request. Ordinary
   classification with a 0.5 threshold could predict every device asleep while
   still giving a fairly small validation loss.
5. **Short training and testing.** The earlier 6-episode/400-TTI demonstration
   was a pipeline check, not the paper's 250 x 10000-TTI training experiment.

## Changes made before searching values

- **Coordinated feasible actions:** learned Q advantages or DT logits rank
  devices within spatial groups, with one eligible sensor per group. A
  rotating tie-break prevents synchronized parameter-sharing decisions. If a
  group has no energy-eligible device, it stays asleep. These action constraints
  are an explicit reconstruction of the paper's clustering/coverage mechanism.
- **Estimated-energy guard:** only BS energy estimates are used to check the
  idle-plus-Tx budget plus a configurable margin. True future EH and true
  unreported battery/observation values are not exposed to the controller.
- **Group-count budget:** an optional cap uses mean input minus WuR overhead
  and an approximate average sensing/Tx cost. It is a conservative planning
  heuristic, not a proof that every stochastic trajectory is energy-neutral.
- **Incremental wake credit:** after a request, its training credit is
  `mu2*(I_after-I_before) - 1/N`. Credits sum to Eq. (25)'s event reward minus
  the state-only term `mu2*I_initial`. An assertion checks this identity during
  simulation. The tuned wake learner uses a within-event contextual-bandit
  update (wake discount 0); the idle learner retains temporal Q-learning.
- **Reporting-based checkpoint selection:** use delivered information minus
  an explicit small measured-energy cost, evaluated on independent rollouts.
- **Balanced DT loss:** positive-class weights come only from training labels.
  At wake inference, the weighting offset is removed before applying the
  calibrated threshold. The coordinated idle decoder prevents all-sleep
  threshold collapse, while the energy guard can still legitimately select
  no devices when no estimated budget is available.

These are algorithmic reconstruction choices, not recovered source details or
only cosmetic coefficient changes. The older independent/global-credit
configuration remains available through `paper_config` for comparison.

## Search and validation protocol

`tune_rl_dt` evaluates four RL candidates and two DT candidates. In quick
calibration, the RL candidates vary group scale, energy margin, mu1, mu2,
learning rate, and discount. The DT candidates vary width, context, heads,
feed-forward size, learning rate, wake threshold, and desired-return quantile.
Both DT candidates use the selected RL sensing budget to avoid imposing a
method ordering through different group counts.

Training streams, Q-checkpoint validation, calibration validation, and final
test streams have disjoint seeds. All candidates receive the same calibration
deployments and exogenous validation streams. The scalar selection score is
mean information per actual event, with no energy term. The Q-training
checkpoint retains its explicit small resource regularizer; the final model
and hyperparameter comparison is based only on information. Published figure
values do not enter this score. No plotted metric is scaled,
sorted, overwritten, or selected by closeness to a target curve.

Quick calibration uses N=[50,250], eight RL episodes of 800 TTIs, two
calibration rollouts of 1500 TTIs per count, and 200/300 DT updates. It is a
limited search and can overfit its validation cases; fresh test deployments
are therefore reported separately. `tune_rl_dt(model,'extended')` uses larger
budgets. The full article-sized evaluation/training budget is selectable with
`recommended_config(model,'paper_budget')` and can take a long time.

The saved `output_calibration_*/calibration.csv` gives every candidate's actual
validation information, misses, energy, group count, score, and setup runtime.
`calibration.mat` includes the selected settings and the complete configuration.
`TUNING_RESULTS.md` records the executed tests and numerical findings.

## Why tuning alone cannot establish an exact figure match

For max aggregation, uniform event locations, eta=1, Psi=1, N=250, and a
20 x 20 m area, the expected closest-device information for uniform random
deployments is about 0.553 even with unlimited energy and perfect selection.
There is also an upper bound of **0.63053 for ANY placement** under these
assumptions. The reported RL value near 0.72 therefore requires a different
area, sensing decay, aggregation convention, event distribution, or related
model detail. The source archive uses 10 x 10 m, for which the same random-
deployment ideal is about 0.734. This is evidence of a possible area mismatch,
not proof of which settings produced the published figure.

The placement bound follows from
`Pr(nearest_distance <= r) <= min(1, N*pi*r^2/area)`.
Let `R=sqrt(area/(N*pi))`. Integrating `exp(-eta*r)` against this optimistic
distance distribution yields
`2*(1-(1+eta*R)*exp(-eta*R))/(eta*R)^2` when `d_max>=R`.
No learning policy can beat this expected-information bound in the stated
max-information model.

Energy has a separate unresolved baseline: Table III does not clearly identify
E_B or numerical TTI duration. With the reconstruction's E_B=1 and TTI=1,
mean harvested input is 0.09516 units/TTI, and initially full batteries allow
at most about 0.10516 actual drain per TTI over 10000 TTIs in expectation.
With E_B=5, that bound becomes about 0.48581. The first bound is conditional on
the assumed quantum; it does not establish that the paper used that quantum.
Changing E_B cannot resolve the geometric information limit.

Run `run_reproduction_audit` to regenerate the geometry/energy checks. Until
those baseline settings are resolved, the two model profiles and their test
results must remain separately labeled. An apparent visual match obtained by
silently changing them would not be a validated reproduction.
