function report = validate_information_detection()
%VALIDATE_INFORMATION_DETECTION Task ranking, coverage, causal feedback, freeze.
c=information_detection_config('archive_compatibility');
a.info_per_event=.70; a.misdetection=.30;
b.info_per_event=.65; b.misdetection=.02;
assert(information_detection_objective(b,c)>information_detection_objective(a,c));
assert(isequal(pareto_information_detection([.6 .7 .5 .65],[.1 .2 .2 .05]),[false;true;false;true]));
assert(idle_task_reward(0,true,2,10,c)<idle_task_reward(0,false,2,10,c));
assert(idle_task_reward(.8,true,2,10,c)>idle_task_reward(.3,true,2,10,c));

% Geometry decoder must respect estimated energy and the awake budget.
rng(107,'twister'); dev=PPP(c.A,c.B,20);
p.type='rl'; p=configure_learning_control(p,dev,c,'rl');
estimate=80*ones(20,1); estimate(1)=0;
plan=learning_idle_actions(zeros(20,1),estimate,1,p.control,0);
assert(~plan(1) && sum(plan)<=p.control.awake_budget);
assert(~any(learning_idle_actions(ones(20,1),zeros(20,1),1,p.control,0)));

% Fast lookup must retain the old interp2 values, including grid edges.
lookup=correlation_lookup(c); D=sqrt(bsxfun(@minus,dev(:,1),dev(:,1)').^2+...
    bsxfun(@minus,dev(:,2),dev(:,2)').^2);
information=c.Psi*exp(-c.eta*linspace(0,c.active_distance,20)');
[~,fast]=wake_close_device(D,information,false(20,1),c,lookup);
reference=zeros(20,1);
for h=1:20
    radius=-log(information(h)/c.Psi)/c.eta;
    reference=max(reference,interp2(lookup.gamma,lookup.r,lookup.value,D(:,h),radius*ones(20,1),'linear'));
end
assert(max(abs(fast-reference))<1e-12,'Fast wake lookup changed interpolation values.');

% Offline RTG may use simulator missed-event labels. Shifted INPUT reward
% must contain only feedback observable to the BS.
log.state=zeros(3,16); log.action=[1 0;0 1;1 0];
log.reward=[-10;2;-10]; log.feedback_reward=[0;2;0]; log.eligible=true(3,2);
trajectory=dt_prepare_trajectory(log,0,.9);
assert(isequal(trajectory.X(:,19),[0;0;2]));
assert(trajectory.returns(1)<0);

c.methods={'rl','dt'}; c.N_values=12; c.MCarlo=1; c.total=150;
c.rl.episodes=3; c.rl.steps=160; c.rl.validation_steps=150; c.rl.validation_trials=1;
c.dt.data_episodes=4; c.dt.data_steps=180;
c.dt.updates=20; c.dt.batch_size=4; c.dt.validation_windows=6;
c.dt.checkpoint_every=10; c.dt.rollout_validation_steps=100; c.dt.rollout_validation_trials=1;
c.make_plots=false; c.save_results=false; c.capture_trace=false; c.verbose=false;
R=run_experiments(c); dt=R.policy{2};
assert(isfield(dt,'dt_selection') && isfinite(dt.dt_selection.rows(dt.dt_selection.selected_row,5)));
assert(~isfield(dt.dt.idle,'checkpoints'),'Unselected training snapshots were not removed.');
assert(isequal(R.policy{1}.q_idle,dt.teacher.q_idle),'The frozen RL teacher was not reused.');

% An event wholly outside detection range cannot be observed by the BS.
% Changing only such unseen labels must not change future DT decisions.
c.collect_learning=true; s=make_scenario(c,12,741,dt.deployment);
s.event_occurs=false(c.total,1); s.event_position(:,:)=1e6;
other=s; other.event_occurs=true(c.total,1);
[m,a,after]=simulate_network(c,s,dt,false);
[~,b]=simulate_network(c,other,dt,false);
assert(isequal(a.learning.idle.action,b.learning.idle.action),'Unseen misses leaked into online DT inputs.');
assert(isequaln(dt.dt,after.dt),'Evaluation changed transformer weights.');
c.rl.reward_mode='paper'; c.dt.observable_feedback=true;
[~,a]=simulate_network(c,s,dt,false); [~,b]=simulate_network(c,other,dt,false);
assert(isequal(a.learning.idle.action,b.learning.idle.action),'Paper-reward feedback leaked unseen misses.');
assert(max(R.raw.budget_error(:))<1e-7 && m.budget_error<1e-7);
report.maximum_energy_error=max(R.raw.budget_error(:));
report.information=R.mean.info_per_event; report.miss_fraction=R.mean.misdetection;
report.dt_selection=dt.dt_selection;
fprintf('Joint objective, coverage, observed feedback, rollout selection and frozen teacher checks passed.\n');
end
