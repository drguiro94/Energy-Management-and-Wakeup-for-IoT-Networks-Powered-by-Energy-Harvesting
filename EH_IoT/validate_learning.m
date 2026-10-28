function report = validate_learning()
%VALIDATE_LEARNING End-to-end learning and information-leakage checks.
addpath(fileparts(mfilename('fullpath')));
report.transformer=validate_transformer();
c=paper_config('quick'); c.methods={'rl','dt'};
c.N_values=10; c.MCarlo=1; c.total=100;
c.rl.episodes=3; c.rl.steps=120; c.rl.validation_steps=80;
c.dt.data_steps=120; c.dt.updates=25; c.dt.batch_size=4;
c.dt.validation_windows=6; c.capture_trace=false;
c.make_plots=false; c.save_results=false; c.verbose=false;
R=run_experiments(c); rl=R.policy{1}; dt=R.policy{2};
assert(any(rl.q_idle(:,1)~=0),'Idle-stage Q table was not learned.');
assert(any(rl.q_wake(:,1)~=0) || any(rl.q_wake(:,2)~=0.02),'Wake-stage Q table was not learned.');
assert(all(isfinite(dt.dt.idle.net.parameters.Win(:))) && isfinite(dt.dt.wake.validation_loss));
assert(~ismember(dt.data_summary.validation_episode,dt.data_summary.training_episode_indices));
assert(dt.data_summary.wake_training_decisions>0 && dt.data_summary.wake_validation_decisions>0);

%% Known discounted return and shifted action/reward alignment.
log.state=zeros(3,16); log.action=[0 1;1 0;1 1];
log.reward=[1;2;3]; log.eligible=true(3,2);
t=dt_prepare_trajectory(log,0,0.5);
assert(max(abs(t.returns-[1.375;1.75;1.5]))<1e-12);
assert(isequal(t.X(:,17:18),[0 0;0 1;1 0]),'Current action leaks into its input token.');
assert(isequal(t.X(:,19),[0;1;2]),'Current reward leaks into its input token.');

%% Freeze test: evaluation changes neither Q tables nor transformer weights.
s=make_scenario(c,10,1234);
for p={rl,dt}
    policy=p{1}; [m1,~,after]=simulate_network(c,s,policy,false);
    m2=simulate_network(c,s,policy,false);
    assert(isequal(m1.information_sum,m2.information_sum),'Frozen evaluation is not deterministic.');
    if strcmp(policy.type,'rl')
        assert(isequal(policy.q_idle,after.q_idle) && isequal(policy.q_wake,after.q_wake));
    else
        assert(isequal(policy.dt.idle.net,after.dt.idle.net) && isequal(policy.dt.wake.net,after.dt.wake.net));
    end
    assert(m1.budget_error<1e-7);
end

%% A learned wake action is executed even when no greedy gain rule would act.
one=c; one.total=1; one.alpha=1; one.lambda=0;
scenario=make_scenario(one,2,11,[0 0;0.2 0]);
scenario.initial_battery=[100;20]; scenario.event_occurs=true;
scenario.event_position=[0 0]; scenario.harvest=false(2,1);
p=rl; p.q_idle=zeros(1440,2); p.q_idle(:,1)=1;
state=q_state([100;20],[0;0],0,[0;0],[0;0],2,one);
p.q_idle(state(1),:)=[0 1]; p.q_wake=zeros(1440,2); p.q_wake(:,2)=1;
m=simulate_network(one,scenario,p,false);
assert(m.wakes_per_event==1,'The second learned control stage is not executed.');

%% Future evaluation events cannot affect earlier chosen actions.
c.collect_learning=true; s=make_scenario(c,10,2001); other=s;
other.event_position(51:end,:)=0; other.event_occurs(51:end)=~other.event_occurs(51:end);
[~,a]=simulate_network(c,s,dt,false); [~,b]=simulate_network(c,other,dt,false);
assert(isequal(a.learning.idle.action(1:50,:),b.learning.idle.action(1:50,:)),...
    'Future physical events leaked into a prior control decision.');
report.wake_training_decisions=dt.data_summary.wake_training_decisions;
report.wake_validation_decisions=dt.data_summary.wake_validation_decisions;
report.idle_validation_loss=dt.dt.idle.validation_loss;
report.wake_validation_loss=dt.dt.wake.validation_loss;
fprintf('Two-stage RL, offline DT, frozen inference, and trajectory leakage checks passed.\n');
end
