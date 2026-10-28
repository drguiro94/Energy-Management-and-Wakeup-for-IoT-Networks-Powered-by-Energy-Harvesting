function policy = select_dt_rollout_checkpoint(policy,dev,cfg,seed)
%SELECT_DT_ROLLOUT_CHECKPOINT Select FROZEN networks by delivered task metrics.
% BCE holdout remains separate from these closed-loop validation rollouts.
% This choice is completed before any final-test scenario is generated.
idle=policy.dt.idle; wake=policy.dt.wake;
pairs={policy.dt};
if isfield(idle,'checkpoints') && isfield(wake,'checkpoints')
    % Two extra time-matched pairs bound selection cost. Keep the BCE-best
    % pair as a candidate even if it falls between these saved checkpoints.
    count=min(numel(idle.checkpoints),numel(wake.checkpoints));
    indices=unique(max(1,round(linspace(1,count,min(2,count)))));
    for j=indices
        next=policy.dt;
        next.idle=use_snapshot(idle,idle.checkpoints{j});
        next.wake=use_snapshot(wake,wake.checkpoints{j});
        pairs{end+1}=next;
    end
end
c=cfg; c.total=cfg.dt.rollout_validation_steps; c.burn_in=0;
c.capture_trace=false; c.collect_learning=false;
scenarios=cell(cfg.dt.rollout_validation_trials,1);
for t=1:numel(scenarios), scenarios{t}=make_scenario(c,size(dev,1),seed+t,dev); end
thresholds=unique([cfg.dt.wake_threshold 0.40]);
rows=[]; best=-Inf; best_dt=policy.dt;
for k=1:numel(pairs)
    for threshold=thresholds
        candidate=policy; candidate.dt=pairs{k};
        candidate.dt.wake.action_threshold=threshold;
        values=zeros(numel(scenarios),3);
        for t=1:numel(scenarios)
            m=simulate_network(c,scenarios{t},candidate,false);
            values(t,:)=[m.info_per_event m.misdetection information_detection_objective(m,cfg)];
        end
        average=mean(values,1);
        rows(end+1,:)=[k threshold average candidate.dt.idle.selected_checkpoint_update...
            candidate.dt.wake.selected_checkpoint_update]; 
        if average(3)>best, best=average(3); best_dt=candidate.dt; selected=size(rows,1); end
    end
end
if isfield(best_dt.idle,'checkpoints'), best_dt.idle=rmfield(best_dt.idle,'checkpoints'); end
if isfield(best_dt.wake,'checkpoints'), best_dt.wake=rmfield(best_dt.wake,'checkpoints'); end
policy.dt=best_dt;
policy.dt_selection.rows=rows; policy.dt_selection.selected_row=selected;
policy.dt_selection.columns={'pair','wake_threshold','information_per_event','miss_fraction',...
    'joint_objective','idle_update','wake_update'};
policy.dt_selection.seed=seed; policy.dt_selection.steps=c.total;
policy.dt_selection.trials=numel(scenarios); policy.dt_selection.objective='I/Psi - miss_weight*miss_fraction';
end

function model=use_snapshot(model,snapshot)
model.net=snapshot.net; model.selected_checkpoint_update=snapshot.update;
model.validation_loss=snapshot.validation_loss;
end
