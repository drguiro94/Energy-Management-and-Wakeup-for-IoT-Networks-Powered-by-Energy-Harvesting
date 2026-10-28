# Model choices and reproduction limits

## Scope and provenance

The uploaded PDF is the expanded 2026 journal paper. The uploaded ZIP README
identifies the earlier 2024 Asilomar contribution. The ZIP contains the random,
adjusted-duty, and k-means scenario sketches, several incomplete utilities,
magazine plotting code, and a custom transformer layer. It does not contain
the full journal RL/DT experiment drivers, tuned hyperparameters, models,
training data, or numerical result MAT files.

This deliverable preserves MATLAB and the original helper-function organization.
It fixes execution errors and reconstructs missing experiment infrastructure.
The update also implements both RL decision stages and complete decision
transformer training/inference. Those learning implementations are NEW
reconstructions from the paper; original source and trained weights were not
recovered. The choices below are explicit. This is not an exact replication archive.

## Parameters and the energy budget

The listed physical parameters are taken from journal Table III: 20 x 20 m,
alpha=0.1, eta=1, Psi=1, d_max=4 m, lambda=0.1, E_max=100, E_idle=1,
E_Tx=10, and E_WuR=1/14. E_B=1 and normalized TTI=1 are explicit choices in
this reconstruction. The paper uses E_B=1 in a toy example, but Table III does
not establish the arrival quantum or numerical TTI duration for Figs. 7-12.
They must therefore not be described as confirmed baseline settings. All
energies remain normalized units; no physical Joule conversion is hard-coded.

Under Eq. (5), these harvesting inputs imply a mean input of
`(1-exp(-0.1))*1 = 0.09516258` energy units per device per TTI. With an initial
full battery and 10000 measured TTIs, conservation bounds the mean actual
drain by roughly `0.10516258`, before finite-buffer overflow losses, in
expectation. Several consumption values discussed for Fig. 8 are above that
bound. They cannot all represent sustained actual battery drain under THIS
choice of duration and quantum. A different unreported quantum/duration could
resolve the energy discrepancy. This conditional energy check does not by
itself establish an error in the paper. Both E_B and TTI remain configurable.

Therefore this implementation exports BOTH actual drained energy and requested
energy. An energy-starved action does not spend energy that does not exist.
It also exports raw harvested input, stored input, overflow, net input, and
battery drift, making this discrepancy inspectable rather than masking it.
The `archive` profile explicitly exposes the older uniform-[0,1] arrival
model (mean 0.5) and older area/range/cost settings; it is not the journal model.

## Sensing probability versus information strength

Section IV specifies event activation probability alpha*p(d), whereas the
supplied `check_active.m` comments out that random draw and detects every event
within a finite range. The genie definition also assumes that the closest
device always detects an in-range event. The default `detection_model='range'`
preserves the supplied executable convention. Set `'bernoulli'` to apply the
additional p(d) detection probability. Both conventions send information
Psi*p(d) on a successful report. These conventions have different expected
information and must not be silently interchanged.

The default information aggregator is max, following the journal's described
maximum-information scenario and Algorithm 1. `sum_saturated` implements
Eq. (3). The uncapped `sum` used in the conference scripts is retained only as
an explicit option and in the archive profile. It can exceed Psi.

## Battery ordering and failures

Eq. (6)'s combined clipping and Eq. (7)'s spend-then-harvest expressions differ
near an empty battery. The simulation consistently uses the causal ordering
in Eq. (7): current actions spend existing energy; remaining charge is clipped
at zero; end-of-slot harvested energy is then stored up to E_max. An action
with inadequate energy fails and consumes the residual charge, following the
failure description in Section III-A. Harvest arriving at the end of a slot
cannot rescue an earlier transmission.

The paper's state S2 is transient and its separate energy is neglected.
Consistent with Eq. (20) and the source scripts, an initially ON device pays
E_idle for its state and additionally E_Tx when it attempts a report. A
sleeping device pays E_WuR, and a later intra-slot BS request adds E_idle plus
the Tx cost if the event is sensed. This explicitly treats wake/report work as
additional intra-slot operations. Each device is requested at most once per
event. These subactions do not create extra ambient energy arrivals or events.

Actual batteries enforce a local E_idle threshold for scheduled activation.
The practical BS wakeup policy never inspects true battery state, true event
position, or unreported event strengths. It may therefore make unsuccessful
requests, as in the paper's wrong-activation metric. The optional shared-Q
reference uses a simple mean-energy predictor, not an unavailable published
posterior estimator. Its expected harvest increments do not enter the true
battery or the energy ledger.

The Markov demonstration uses exactly the same cost-then-EH boundary rule.
Its step 1/14 represents E_WuR, E_idle, E_Tx, and E_B exactly in normalized
units. This is finer than a literal integer-E_B grid, needed because the
paper includes a fractional WuR cost. The demonstration conditions on an
explicit fixed action mixture; an adaptive network requires a larger joint
controller/battery state, so those stationary probabilities are not falsely
used as the adaptive network's analytical solution.

## Duty cycling, clusters, and information targets

The original main loops passed the constant TTI duration instead of an
advancing slot index to the duty-cycle helpers. The cleaned scheduler uses
`mod(k-1+phase,L)<ell`, so the ON window actually rotates.

The source's purported KNN scenario calls MATLAB kmeans with ten clusters,
while the journal describes a KNN graph/majority assignment and Algorithm 1
sets M=area/(pi*d_max^2). The cleaned code preserves the archive's **k-means
family**, implements it without a toolbox, and sets
M=min(N,max(1,ceil(area/(pi*d_max^2)))). Figures label this policy
`Cluster-based (source k-means)`; it must not be presented as an exact
implementation of the journal's underspecified KNN majority procedure.
There is one scheduled ON device per cluster per slot. A scheduled device
without E_idle remains asleep; the BS does not use hidden battery values to
replace it with an oracle-selected member.

The finite monitored rectangle clips every Voronoi cell. The maximum
site-to-vertex distance defines the target Psi*exp(-eta*d_star), as in
Eq. (21). For a square centered grid with a square number of devices this
recovers Eq. (22). Without clipping, exterior Voronoi cells would be unbounded.
This is a geometric information target, not a guarantee that the network
achieves that mean under arbitrary sensing, energy, or scheduling losses.

Adjusted duty cycling searches a configurable finite set of common ON/cycle
pairs. It uses independent pilot events/EH on the same deployment, selecting
minimum actual energy among candidates whose pilot information meets the
target. If none is feasible, it records `policy.search.feasible=false` and
selects the largest pilot information, breaking ties by lower energy. It does
not claim that the constraint was met. It does not exhaust every possible
individual-device schedule, and its choice should be independently tested.

## On-demand wakeup and the genie

The BS infers a successful reporter's distance from its normalized strength
and averages Eq. (15) over the unknown uniform bearing. Scores outside the
sensing range contribute zero. It takes the maximum score over current
reporters, applies p(d_max) as a candidate threshold, and queries the highest
score first. The heuristic policies recompute the ranking after successful extra reports. This
is a geometric sensing-score proxy, not an exact learned conditional reporting
probability or an exact posterior accounting for boundary effects and energy.
For eta=0 the strength carries no distance information; the current helper
uses a distance-only proxy (reported in its comment). The main paper uses eta=1.

Wakeups require an actual positive initial report. Already-ON/queried devices
are excluded, ties have stable device-index order, and the true event location
is used only by the physical observation function. The source's fixed device
index order, repeated reports, and incorrect neighbor-update loop are removed.

The default genie is the closest-device **finite-battery** scenario. It is
energy-limited and therefore is not a strict information upper bound on every
sample path: a different device may have more energy. Setting
`genie_ignore_battery=true` explicitly creates an ideal sensing-information
bound; its delivered information is then virtual when energy is insufficient,
and its drain metrics must not be interpreted as a physically feasible policy.
This distinction resolves the paper's conflicting ideal-upper-bound and
finite-energy-failure descriptions without combining them silently.

## Reconstructed RL and decision transformers

The `rl` policy now learns BOTH stages: per-slot binary duty cycling with
Eq. (24), and a joint binary extra-report vector at a detected event with
Eq. (25). The stages have separate shared 1440 x 2 Q tables. Idle-stage TD
updates follow the TTI clock, whereas wake-stage TD updates follow successive
detected events with eligible sleeping devices. Extra reports selected by the
learned joint vector execute in initial correlation-score order. This is a
joint second-stage action, not an adaptive re-decision after each new report.
Both tables are frozen during evaluation; there is no greedy marginal-gain
substitute in this policy. Held-out simulation episodes select the checkpoint.

The `dt` policy now has a complete offline pipeline: train a two-stage RL
behavior policy; collect exploratory copies of its frozen tables plus diverse
baseline rollouts; split entire episodes; construct discounted return-to-go
and shifted-action/reward tokens; train causal multi-head transformers with
Adam; select checkpoints on held-out episodes; and freeze all weights for
evaluation. The two stages use separate networks, and each network predicts a
joint N-device binary vector from the observed global state and temporal
context. Online desired return is initialized from training returns and
updated only using observed rewards, with clipping to training support.

Manual backpropagation trains the input embedding, query/key/value/output
projections, feed-forward layers, layer-norm parameters, and action head.
Finite-difference checks cover every parameter family. No toolbox is needed.

The paper does not supply sufficient code or settings to recover its original
architecture, exact bin edges, tuned weights, Bayesian search results, or
dataset. These choices are therefore documented reconstructions. The DT uses
one concatenated state/previous-action/previous-reward/return token per
decision, rather than claiming to recover the original tokenization. It uses
binary cross-entropy for binary action prediction; tabular RL uses ordinary
TD updates. It does not claim to replicate the Appendix's mixed tabular,
Adam, and RMSE description. See `LEARNING_GUIDE.md` for details.

## Earlier one-stage reference (retained)

`q_reference` is a NEW reproducible implementation. It has a shared 1440 x 2
Q-table, an epsilon-greedy training policy, one-step discounted TD updates,
discretized estimated energy/reported-score/information/neighborhood/duty
features, and a density bin. It uses Eq. (24)'s reward, with the misdetection
indicator evaluated only when an event actually occurs. Training data are
separate from evaluation data. Each deployment is trained separately; models
are frozen during evaluation. Additional wakeups use a greedy marginal-value
comparison with mu2 and 1/N. This simpler reference is separate from the new
two-stage `rl` policy.

This reference does not recreate the paper's Bayesian hyperparameter search,
cross-validation, unspecified bin edges, full second-stage learner, or tuned
weights. It uses ordinary tabular TD updates rather than making an unsupported
claim about the Appendix's mixed tabular/Adam/RMSE description. Its outputs
must be labeled as reference results. Use `rl` and `dt` for the complete
reconstructed learning pipelines.

## Metrics and statistical treatment

Information per expected event is sum(I)/(alpha*K), Eq. (18). Information per
actual event is exported separately as sum(I)/number_of_events. Misdetection
uses actual events. With no actual events, event-conditioned metrics are NaN;
with alpha=0 the expected-event metric is also NaN. Battery and availability
are time averages over all measured TTIs, not terminal snapshots.

An activation opportunity is either an initial sensing device attempting Tx
or a BS-requested extra observation. It fails if it delivers no information.
Wrong percentage is 100*failures/opportunities; wrong count per actual event
is also exported because the paper mixes percentages and counts in its
discussion. Wasted energy sums actual failed Tx drain and extra wake/sensing
drain for failed BS requests, divided by N*actual_event_count. Routine
background idle and sleep costs are not classified as wasted request energy.

95% intervals use Student-t uncertainty across independent deployment means,
not individual correlated TTIs. A one-deployment run has no estimable interval
and exports NaN for that half-width. Zero observed misses do not prove zero
true miss probability. Evaluation streams are shared across methods; pilot
search and optional RL training use disjoint deterministic seeds.

The budget plots corresponding to Figs. 13-14 use p_eh*E_B minus **fixed
baseline measured consumption**. They are analytical planning curves, not
claims that consumption remains fixed after changing harvesting statistics.
`run_sensitivity` actually reruns the simulator when changing alpha. Runtime
plots measure the current computer; setup/tuning time is exported separately.
Memory and reward-sensitivity curves from the journal are not reproduced.
