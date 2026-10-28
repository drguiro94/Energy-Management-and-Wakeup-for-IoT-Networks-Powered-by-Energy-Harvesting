function report = validate_tuning()
%VALIDATE_TUNING Guard against synchronized/all-sleep learning regressions.
addpath(fileparts(mfilename('fullpath')));
c=tuned_config('archive_compatibility'); c.N_values=12;
rng(91,'twister'); dev=PPP(c.A,c.B,12);
p.type='rl'; p=configure_learning_control(p,dev,c,'rl');
for k=1:20
    % Negative logits are deliberately used: independent thresholding would
    % choose all-sleep, whereas the feasible group action remains well-defined.
    plan=learning_idle_actions(-ones(12,1),100*ones(12,1),k,p.control,0);
    for group=unique(p.control.groups)'
        assert(sum(plan(p.control.groups==group))==1);
    end
end
empty=learning_idle_actions(ones(12,1),zeros(12,1),1,p.control,0);
assert(~any(empty),'Energy guard was bypassed to force a report.');
battery=100*ones(12,1); battery(1)=0;
plan=learning_idle_actions([100;zeros(11,1)],battery,1,p.control,0);
assert(~plan(1),'An unavailable device was selected by its high score.');

% Exact identity underlying incremental report credit, including failed and
% redundant requests: sum(credits) + mu2*initial_I = Eq. (25).
levels=[0.1 0.35 0.35 0.7]; count=numel(levels)-1; N=12;
credit=c.rl.mu2*diff(levels)-1/N;
assert(abs(sum(credit)+c.rl.mu2*levels(1)-(c.rl.mu2*levels(end)-count/N))<1e-12);

c.methods={'rl','dt'}; c.MCarlo=1; c.total=120; c.alpha=0.3;
c.rl.episodes=4; c.rl.steps=150; c.rl.validation_steps=120;
c.rl.validation_trials=1; c.dt.data_steps=180; c.dt.data_episodes=4;
c.dt.updates=20; c.dt.batch_size=4; c.dt.validation_windows=6;
c.dt.d_model=16; c.dt.heads=2; c.dt.ff_size=32;
c.make_plots=false; c.capture_trace=false; c.save_results=false; c.verbose=false;
R=run_experiments(c);
assert(max(R.raw.budget_error(:))<1e-7);
assert(R.policy{2}.dt.idle.positive_weight>1,'Class balancing was not applied.');
assert(all(R.raw.energy_actual(:)<=R.raw.energy_requested(:)+1e-10));
assert(all(R.raw.activation_count(:)>0),'The tuned controller collapsed to all-sleep.');
report.maximum_energy_error=max(R.raw.budget_error(:));
report.information=R.mean.info_per_event; report.activations=R.raw.activation_count;
fprintf('Coordinated action, energy guard, wake-credit identity, and balanced DT checks passed.\n');
end
