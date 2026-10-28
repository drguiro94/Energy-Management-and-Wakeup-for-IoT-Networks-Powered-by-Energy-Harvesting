function policy = train_decision_transformer(policy,dev,cfg,seed,teacher)
%TRAIN_DECISION_TRANSFORMER Full simulator -> offline data -> two DT stages.
% The models predict joint N-device action vectors. Their histories reset at
% rollout boundaries, and frozen evaluation never reads offline future returns.
if nargin<5 || isempty(teacher)
    teacher=policy; teacher.type='rl'; teacher.label='DT data-collection teacher';
    teacher=configure_learning_control(teacher,dev,cfg,'rl');
    teacher.q_idle=zeros(1440,2); teacher.q_idle(:,2)=0.05;
    teacher.q_wake=zeros(1440,2); teacher.q_wake(:,2)=0.02;
    teacher_cfg=cfg;
    if cfg.dt.teacher_episodes>0, teacher_cfg.rl.episodes=cfg.dt.teacher_episodes; end
    teacher=train_two_stage_rl(teacher,dev,teacher_cfg,seed+100000);
else
    assert(strcmp(teacher.type,'rl') && isequal(teacher.deployment,dev),...
        'The offline teacher must be a frozen RL policy for this deployment.');
end
c=cfg; c.total=cfg.dt.data_steps; c.burn_in=0;
c.capture_trace=false; c.collect_learning=true;
episodes=cell(cfg.dt.data_episodes+cfg.dt.baseline_episodes,1);
for e=1:cfg.dt.data_episodes
    behaviour=teacher;
    % Frozen teacher tables plus exploration; collection is not DT training.
    behaviour.behaviour_epsilon=0.6-0.55*(e-1)/max(1,cfg.dt.data_episodes-1);
    if isfield(cfg.dt,'data_epsilon_start')
        behaviour.behaviour_epsilon=cfg.dt.data_epsilon_start+...
            (cfg.dt.data_epsilon_end-cfg.dt.data_epsilon_start)*(e-1)/max(1,cfg.dt.data_episodes-1);
    end
    if e==cfg.dt.data_episodes, behaviour.behaviour_epsilon=cfg.dt.validation_epsilon; end
    scenario=make_scenario(c,size(dev,1),seed+150000+e,dev);
    [~,trace]=simulate_network(c,scenario,behaviour,false);
    episodes{e}=trace.learning;
    episodes{e}.seed=seed+150000+e; episodes{e}.behaviour='exploratory frozen two-stage RL';
end
for e=1:cfg.dt.baseline_episodes
    if mod(e,2)==1, name='cluster'; else, name='random'; end
    behaviour=build_policy(name,dev,c,policy.target,seed+160000+e);
    scenario=make_scenario(c,size(dev,1),seed+170000+e,dev);
    [~,trace]=simulate_network(c,scenario,behaviour,false);
    episodes{cfg.dt.data_episodes+e}=trace.learning;
    episodes{cfg.dt.data_episodes+e}.seed=seed+170000+e;
    episodes{cfg.dt.data_episodes+e}.behaviour=name;
end
% Select a distinct RL rollout with actual extra-report decisions for holdout.
holdout=[];
for e=cfg.dt.data_episodes:-1:1
    if ~isempty(episodes{e}.wake.state), holdout=e; break; end
end
assert(~isempty(holdout),'No wake decisions collected. Increase dt.data_episodes or dt.data_steps.');
idle_train={}; idle_validation={}; wake_train={}; wake_validation={};
for e=1:numel(episodes)
    idle=dt_prepare_trajectory(episodes{e}.idle,0,cfg.rl.discount);
    wake=dt_prepare_trajectory(episodes{e}.wake,1,cfg.rl.discount);
    if e==holdout
        idle_validation{end+1}=idle; wake_validation{end+1}=wake; 
    else
        idle_train{end+1}=idle; 
        if ~isempty(wake.X), wake_train{end+1}=wake; end 
    end
end
assert(~isempty(wake_train),'No wake-stage training rollouts remain after holdout. Increase data_episodes.');
policy.dt.idle=train_dt_stage(idle_train,idle_validation,cfg,seed+210000,0);
policy.dt.wake=train_dt_stage(wake_train,wake_validation,cfg,seed+220000,1);
policy.teacher.q_idle=teacher.q_idle; policy.teacher.q_wake=teacher.q_wake;
policy.teacher.training_history=teacher.training_history;
policy.data_summary.episodes=numel(episodes); policy.data_summary.validation_episode=holdout;
policy.data_summary.training_episode_indices=setdiff(1:numel(episodes),holdout);
policy.data_summary.idle_training_decisions=sum(cellfun(@(x)size(x.X,1),idle_train));
policy.data_summary.wake_training_decisions=sum(cellfun(@(x)size(x.X,1),wake_train));
policy.data_summary.idle_validation_decisions=size(idle_validation{1}.X,1);
policy.data_summary.wake_validation_decisions=size(wake_validation{1}.X,1);
if cfg.dt.save_dataset, policy.offline_episodes=episodes; end
if isfield(cfg.dt,'rollout_selection') && cfg.dt.rollout_selection
    policy=select_dt_rollout_checkpoint(policy,dev,cfg,seed+260000);
end
end
