# Information-per-event tuning results

This records the preceding information-only build. The current joint
information/missed-event update is in `JOINT_TUNING_RESULTS.md`. Fresh
configurations now also exclude hidden missed-event labels from DT online
feedback; historical saved models/configurations retain their replay interface.
The exact preceding source snapshot is in
`output_joint_audit/reference_information_only_sources.zip`.

Executed in GNU Octave 8.4.0 on 2026-10-27. No plotted value was fitted, rescaled, sorted, or overwritten.

## Main information result

Under the explicitly labeled **10 x 10 m archive-compatible geometry and uniform [0,1] harvested energy**, the independent 10000-TTI test at N=250 gives RL **0.717057**, DT **0.512966**, and finite-battery genie **0.725073** information units per actual event. This approaches the reported RL information level near 0.72, but does not establish exact reproduction of the full published figure or its other metrics.

Under the separately tested **20 x 20 m, Bernoulli EH, E_B=1 reconstruction**, the corresponding values are RL **0.101395** and DT **0.110526**. The profiles must not be silently interchanged. Their full numerical tables below are authoritative.

## Selected settings

Hyperparameter selection was rescored using only mean information per actual event. This did not change either selected candidate. Candidate validation records remain in `output_calibration_*/calibration.csv`. The RL training-checkpoint procedure retains its explicit small resource regularizer; the final candidate-selection score has no energy term.

| Setting | Stated-model reconstruction | Archive-compatible reconstruction |
|---|---:|---:|
| mu1 | 20 | 5 |
| mu2 | 3 | 5 |
| Q learning rate | 0.01 | 0.01 |
| Idle discount | 0.95 | 0.95 |
| Wake discount | 0 | 0 |
| Spatial group multiplier | 1 | 4 |
| Estimated-energy margin | 2 | 5 |
| DT context | 16 | 16 |
| DT embedding width | 16 | 16 |
| DT attention heads | 2 | 2 |
| DT FFN width | 32 | 32 |
| DT Adam rate | 0.001 | 0.001 |
| DT wake threshold | 0.3 | 0.3 |
| DT desired-return quantile | 0.75 | 0.75 |

Both controllers use coordinated spatial actions, estimated-energy guards, and incremental wakeup credit. DT training balances positive labels, then removes that weighting offset for calibrated wake decisions. See `TUNING_GUIDE.md` for the algorithmic changes, which are explicit reconstruction choices.

## Independent information tests

Each table uses one new deployment per count, 10000 TTIs, and common event/EH streams across methods. Training and tuning use different seeds. These tests establish execution and case-level behavior; they do not establish the paper's 1000-deployment averages or confidence intervals. No deployment-level interval is drawn for a single deployment.

### paper

| N | Random | Clustering | RL | DT | Genie |
|---:|---:|---:|---:|---:|---:|
| 10 | 0.000264 | 0.000968 | 0.003463 | 0.002433 | 0.039655 |
| 50 | 0.006328 | 0.007659 | 0.025412 | 0.016778 | 0.281317 |
| 250 | 0.012585 | 0.137610 | 0.101395 | 0.110526 | 0.542203 |

### archive_compatibility

| N | Random | Clustering | RL | DT | Genie |
|---:|---:|---:|---:|---:|---:|
| 10 | 0.042619 | 0.085770 | 0.137442 | 0.080522 | 0.259641 |
| 50 | 0.167594 | 0.207688 | 0.429481 | 0.310954 | 0.527323 |
| 250 | 0.394531 | 0.300638 | 0.717057 | 0.512966 | 0.725073 |

The N=250 figure endpoints are approximately RL 0.72-0.73 and DT 0.49, read from the uploaded figure/text. The measured 0.717/0.513 values are close at that endpoint. The full curve is not matched: at N=50 the measured RL/DT values are 0.429/0.311, while the plotted values are roughly 0.26/0.26. These approximate paper values are comparison references, not optimization targets.

The archive-compatible RL/DT information levels are closer to Fig. 7; the clustering/random ordering is not identical to the published comparison. No exact-match claim is made for all curves. Under the stated-model reconstruction, the clustering baseline still exceeds both learning methods at N=250 in this test. Those results are retained rather than hidden.

## Paired before/after check in the stated-model reconstruction

The earlier version's saved first-deployment models were re-evaluated on the same deployments, event locations, EH samples, and 10000-TTI horizons used for the corresponding updated tests. Both versions were frozen. Training procedures/settings differ by design, so this compares the complete earlier and updated pipelines, not an isolated ablation.

| N | Earlier RL | Updated RL | Earlier DT | Updated DT |
|---:|---:|---:|---:|---:|
| 10 | 0.000000 | 0.003463 | 0.000065 | 0.002433 |
| 50 | 0.004765 | 0.025412 | 0.000135 | 0.016778 |
| 250 | 0.002194 | 0.101395 | 0.000000 | 0.110526 |

## Normalization and physical audit

The primary plots/values above use `sum(information)/actual_event_count`, including zero-information missed events. `information_per_event.csv` also exports `sum(information)/(alpha*K)`, the normalization in Eq. (18). Missed events are never removed from either calculation.

The regenerated audit gives a uniform-random-deployment ideal of 0.552898 for the 20 m model at N=250. More generally, an any-placement bound is 0.630531 under uniform events and max aggregation. Thus the stated area/decay/max-information assumptions cannot yield expected information near 0.72 by learning-rate or reward tuning alone. The 10 m source geometry has random-deployment ideal 0.733595 and is a plausible explanation of the information scale, not proof of the original experimental settings.

E_B=1 and normalized TTI=1 were assumptions in the reconstruction; the baseline quantum/duration for Figs. 7-12 are not clearly fixed in Table III. This uncertainty remains explicit.

## Artifacts and reproducibility

- `output_information_focus/information_per_event_focus.png`: information-only comparison of both labeled physical profiles.
- `output_tuned_test_*/fig07_information_per_event.png` and `information_per_event.csv`: focused plots and both normalizations.
- `output_calibration_*/calibration.mat` and `.csv`: all measured candidate trials and selected configurations.
- `output_tuned_test_*/models`: the actual frozen RL/DT test policies and their configurations.
- `output_reproduction_audit/physical_bounds.csv`: regenerated geometry and energy checks.
- `output_reproduction_audit/paired_information_before_after.csv`: the paired case-level comparisons.
- `run_information_experiment.m`: repeat the information-only experiment; its alternative physical-model choice is explicit.
- `validate_tuning`, `validate_learning`, `run_validation`: all passed after the changes. Numerical attention-gradient and causality checks are included.

Use `recommended_config(model,'paper_budget')` for the larger budget, or edit the N sweep/trial count in the information runner. The full 250-episode/10000-TTI training and 1000-deployment evaluation were not executed here.
