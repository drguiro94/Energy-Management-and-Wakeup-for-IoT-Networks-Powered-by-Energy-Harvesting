# Joint information and missed-event tuning results

Executed in GNU Octave 8.4.0 on 2026-10-27. The delivered MATLAB code uses no specialist toolboxes.

## What was optimized

`J = information_per_actual_event/Psi - miss_weight*miss_fraction`, with `miss_weight=1`. 
The information denominator includes missed events with zero information. No published coordinate enters the objective. 
Increasing the miss weight emphasizes detection reliability. The Pareto search tables preserve the information/reliability tradeoffs.

The update adds coordinated area coverage, a task-aligned idle reward, better offline teacher data, 
and DT checkpoint/threshold selection on independent closed-loop rollouts. Online DT history excludes unseen missed-event labels. 
See `JOINT_TUNING_GUIDE.md` for the explicit reconstruction choices and reward change.

## Executed evaluation

Each physical profile uses N=[10,50,250], **three independent deployments per N**, and **10000 measured TTIs per deployment**. 
All five policies share deployment/event/EH inputs within each test trial. Training, checkpoint validation, 
outer calibration, and final-test seeds are separate. Test inputs never select or update weights.

Intervals below are 95% Student-t intervals across three deployment means. Three deployments give limited precision. 
A zero observed missed-event fraction is not evidence that the true miss probability is zero or below 0.01%. 
The paper-sized 250-episode training, 25-iteration validation/testing, and 1000-deployment evaluation were not executed.

## Stated-model reconstruction: 20 x 20 m, Bernoulli EH, assumed E_B=1

| N | Method | Information/event | 95% half-width | Missed events (%) | 95% half-width (pp) |
|---:|---|---:|---:|---:|---:|
| 10 | RL | 0.002299 | 0.001337 | 98.101 | 1.030 |
| 10 | DT | 0.002205 | 0.001190 | 98.277 | 0.300 |
| 50 | RL | 0.018686 | 0.000925 | 89.797 | 1.622 |
| 50 | DT | 0.016535 | 0.006161 | 90.627 | 1.522 |
| 250 | RL | 0.082433 | 0.005875 | 61.254 | 2.237 |
| 250 | DT | 0.084266 | 0.009476 | 60.956 | 3.625 |

All methods at N=250:

| Method | Information/event | Missed events (%) |
|---|---:|---:|
| random | 0.013470 | 94.104 |
| cluster | 0.143224 | 53.423 |
| rl | 0.082433 | 61.254 |
| dt | 0.084266 | 60.956 |
| genie | 0.548248 | 0.000 |

Selected global calibration settings:

| Setting | Value |
|---|---:|
| RL candidate / DT candidate | 3 / 1 |
| mu1 / mu2 | 5 / 5 |
| Q learning rate / idle discount / wake discount | 0.01 / 0.95 / 0 |
| Spatial budget multiplier / energy margin | 1 / 5 |
| Optional mean-EH cap enabled | False |
| Learned-score / estimated-energy preference | 0.25 / 0.75 |
| DT context / embedding / heads / FFN | 16 / 16 / 2 / 32 |
| DT Adam rate / maximum updates | 0.001 / 200 |
| DT configured wake threshold / return quantile | 0.2 / 0.75 |

The actual per-deployment DT wake threshold and checkpoint are selected on separate validation rollouts. 
They are saved in each model and `policy.dt_selection`, rather than chosen from the final test.

Outer calibration (equal weight per validation device count):

| Method | Candidate | Information/event | Missed events (%) | Joint score | Pareto |
|---|---:|---:|---:|---:|---|
| RL | 1 | 0.058727 | 78.535 | -0.726626 | yes |
| RL | 2 | 0.041130 | 80.117 | -0.760044 | no |
| RL | 3 | 0.048851 | 76.625 | -0.717403 | yes |
| DT | 1 | 0.048718 | 76.731 | -0.718590 | yes |
| DT | 2 | 0.048976 | 77.437 | -0.725389 | yes |

## Archive-compatible reconstruction: 10 x 10 m, uniform [0,1] EH

| N | Method | Information/event | 95% half-width | Missed events (%) | 95% half-width (pp) |
|---:|---|---:|---:|---:|---:|
| 10 | RL | 0.107576 | 0.073694 | 58.541 | 25.161 |
| 10 | DT | 0.093321 | 0.080376 | 64.370 | 29.346 |
| 50 | RL | 0.493666 | 0.051157 | 2.923 | 5.640 |
| 50 | DT | 0.438379 | 0.042505 | 5.962 | 10.223 |
| 250 | RL | 0.714747 | 0.027472 | 1.281 | 1.652 |
| 250 | DT | 0.636566 | 0.047701 | 10.975 | 9.722 |

All methods at N=250:

| Method | Information/event | Missed events (%) |
|---|---:|---:|
| random | 0.416046 | 0.000 |
| cluster | 0.324281 | 39.556 |
| rl | 0.714747 | 1.281 |
| dt | 0.636566 | 10.975 |
| genie | 0.729957 | 0.000 |

Selected global calibration settings:

| Setting | Value |
|---|---:|
| RL candidate / DT candidate | 1 / 2 |
| mu1 / mu2 | 10 / 5 |
| Q learning rate / idle discount / wake discount | 0.01 / 0.95 / 0 |
| Spatial budget multiplier / energy margin | 4 / 2 |
| Optional mean-EH cap enabled | True |
| Learned-score / estimated-energy preference | 0.15 / 0.25 |
| DT context / embedding / heads / FFN | 16 / 32 / 4 / 64 |
| DT Adam rate / maximum updates | 0.001 / 200 |
| DT configured wake threshold / return quantile | 0.15 / 0.9 |

The actual per-deployment DT wake threshold and checkpoint are selected on separate validation rollouts. 
They are saved in each model and `policy.dt_selection`, rather than chosen from the final test.

Outer calibration (equal weight per validation device count):

| Method | Candidate | Information/event | Missed events (%) | Joint score | Pareto |
|---|---:|---:|---:|---:|---|
| RL | 1 | 0.603971 | 1.713 | 0.586837 | yes |
| RL | 2 | 0.545727 | 8.827 | 0.457460 | no |
| RL | 3 | 0.596425 | 3.232 | 0.564103 | no |
| DT | 1 | 0.536700 | 8.300 | 0.453704 | no |
| DT | 2 | 0.549059 | 7.606 | 0.473001 | yes |

## Paired before/after comparison

The earlier information-only models and the updated first test deployment use identical geometry, 
events, harvesting samples, and 10000-TTI horizons. Equality of all three unchanged baselines 
was checked numerically. Both learning pipelines are frozen during testing. 
These rows compare complete pipelines, not an isolated reward-weight ablation; the three-deployment means above are separate.

| Model | N | Method | Earlier information | Updated information | Earlier misses (%) | Updated misses (%) |
|---|---:|---|---:|---:|---:|---:|
| 20 m | 10 | RL | 0.003463 | 0.001745 | 97.665 | 98.579 |
| 20 m | 10 | DT | 0.002433 | 0.001917 | 97.868 | 98.376 |
| 20 m | 50 | RL | 0.025412 | 0.018259 | 91.086 | 89.857 |
| 20 m | 50 | DT | 0.016778 | 0.019391 | 92.828 | 89.959 |
| 20 m | 250 | RL | 0.101395 | 0.082679 | 69.760 | 60.279 |
| 20 m | 250 | DT | 0.110526 | 0.088589 | 69.661 | 59.281 |
| 10 m | 10 | RL | 0.137442 | 0.077789 | 52.487 | 69.442 |
| 10 m | 10 | DT | 0.080522 | 0.056374 | 70.558 | 77.970 |
| 10 m | 50 | RL | 0.429481 | 0.513991 | 10.041 | 0.410 |
| 10 m | 50 | DT | 0.310954 | 0.457861 | 32.172 | 1.537 |
| 10 m | 250 | RL | 0.717057 | 0.703595 | 0.798 | 1.597 |
| 10 m | 250 | DT | 0.512966 | 0.625875 | 28.044 | 12.575 |

## Interpretation and reproduction limits

The update is not a uniform improvement. In the paired 10 m case, both
learners regress at N=10; at N=250 RL also regresses slightly, while DT gains
information and reduces missed events. In the 20 m N=250 case, both reduce
misses while losing information. The selected settings maximize the declared
joint validation score over the measured grid; they do not establish a global
optimum or outperform the earlier pipeline for every deployment or density.

The 10 m profile is an explicitly labeled alternative taken from the source ZIP geometry and harvest convention. 
It is **not** the journal Table III profile. Its values must not be substituted for the 20 m results without saying so.

For uniform events, eta=1, max aggregation and N=250 in a 20 x 20 m area, the any-placement 
information upper bound is about 0.6305 before any battery/scheduling loss. The reported RL level 
near 0.72 cannot be obtained under those exact assumptions by tuning learning parameters. 
E_B=1 and TTI=1 remain explicit reconstruction assumptions; the source lacks full journal RL/DT code and trained weights.

The aim here is measured information/detection performance. The update does not fit the paper plot, 
guarantee the paper rankings, establish a global optimum, or claim exact numerical reproduction. 
All weak results and information/reliability tradeoffs are retained in the tables and CSVs.

## Ready-to-run files and evidence

- `run_information_detection_experiment.m` or `run_rl_dt.m`: current joint task; default is the 20 m stated-model reconstruction.
- `recommended_information_detection_config.m`: measured settings with portable output paths.
- `output_joint_test_*/information_detection.csv`: both normalizations, actual event/miss counts, and intervals.
- `output_joint_test_*/fig07_information_per_event.png` and `fig09_misdetection.png`: fresh plots.
- `output_joint_test_*/models`: all actual frozen RL/DT policies and their configurations.
- `output_joint_calibration_*/calibration.csv` and `pareto_summary.csv`: every measured candidate.
- `output_joint_audit/paired_before_after.csv`: exact first-deployment comparisons.
- `output_joint_audit/reference_information_only_sources.zip`: the preceding source snapshot.
- `output_joint_audit/validation.log`: the executed implementation checks.

Validation passed: physical model limits/conservation, 84 transformer finite-difference gradient checks 
(maximum scaled error 9.58e-12), future masking, offline episode separation, frozen inference, 
coverage/energy guards, Pareto selection, and invariance to unseen missed-event labels. 
An equivalent fast wakeup interpolation and scalar battery update were checked against frozen-policy 
reference runs with no change in measured information or missed-event results.
