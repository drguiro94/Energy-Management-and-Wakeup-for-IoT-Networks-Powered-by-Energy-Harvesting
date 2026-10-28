function policy = build_policy(name,dev,cfg,target,seed,teacher)
%BUILD_POLICY Deployment-specific fixed duty cycles or a trained reference.
rng(seed,'twister'); N=size(dev,1);
if nargin<6, teacher=[]; end
policy.type=name; policy.target=target;
policy.deployment=dev; % Required to reuse a deployment-specific trained model.
policy.cycle=ones(N,1); policy.on_time=ones(N,1); policy.phase=zeros(N,1);
policy.cluster_idx=[]; policy.centroids=[];
policy.lookup=correlation_lookup(cfg);
switch name
    case 'random'
        policy.cycle=cfg.random_cycles(randi(numel(cfg.random_cycles),N,1));
        policy.cycle=policy.cycle(:);
        policy.on_time=cfg.random_on_times(randi(numel(cfg.random_on_times),N,1));
        policy.on_time=min(policy.cycle,policy.on_time(:));
        policy.phase=floor(rand(N,1).*policy.cycle);
        policy.label='Random duty cycling';
    case 'cluster'
        [idx,cent,~,cycle,phase]=kmeans_cluster(dev,cfg);
        policy.cluster_idx=idx; policy.centroids=cent;
        policy.cycle=cycle; policy.phase=phase;
        policy.label='Cluster-based (source k-means)';
    case 'adjusted'
        policy=select_duty_cycle(policy,dev,cfg,seed);
        policy.label='Adjusted duty cycling';
    case 'genie'
        if cfg.genie_ignore_battery
            policy.label='Genie (ideal information bound)';
        else
            policy.label='Genie (finite battery)';
        end
    case 'q_reference'
        policy.label='Shared-Q reference (new)';
        policy.q=zeros(1440,2); policy.q(:,2)=0.05;
        policy=train_q_reference(policy,dev,cfg,seed);
    case 'rl'
        policy.label='RL: two learned stages (reconstructed)';
        policy=configure_learning_control(policy,dev,cfg,'rl');
        policy.q_idle=zeros(1440,2); policy.q_idle(:,2)=0.05;
        policy.q_wake=zeros(1440,2); policy.q_wake(:,2)=0.02;
        policy=train_two_stage_rl(policy,dev,cfg,seed);
    case 'dt'
        policy.label='Decision transformer (reconstructed)';
        policy=configure_learning_control(policy,dev,cfg,'dt');
        policy=train_decision_transformer(policy,dev,cfg,seed,teacher);
end
end

function p=select_duty_cycle(p,dev,cfg,seed)
% Separate pilot streams prevent optimization on held-out evaluation events.
pilot_cfg=cfg; pilot_cfg.total=cfg.search_total; pilot_cfg.burn_in=0;
pilot_cfg.capture_trace=false; pilot_cfg.save_results=false;
pilots=cell(cfg.search_MCarlo,1);
for rep=1:cfg.search_MCarlo
    pilots{rep}=make_scenario(pilot_cfg,size(dev,1),seed+1000+rep,dev);
end
rows=[]; phases=rand(size(dev,1),1);
for L=cfg.adjusted_cycles
    for ell=cfg.adjusted_on_times
        if ell>L, continue; end
        cand=p; cand.cycle=L*ones(size(dev,1),1);
        cand.on_time=ell*ones(size(dev,1),1); cand.phase=floor(phases*L);
        infoval=zeros(cfg.search_MCarlo,1); energy=infoval;
        for rep=1:cfg.search_MCarlo
            m=simulate_network(pilot_cfg,pilots{rep},cand,false);
            infoval(rep)=m.info_per_expected_event; energy(rep)=m.energy_actual;
        end
        rows(end+1,:)=[L ell mean(infoval) mean(energy)]; 
    end
end
feasible=rows(:,3)>=p.target;
if any(feasible)
    candidates=find(feasible); [~,i]=min(rows(feasible,4)); selected=candidates(i);
else
    % A geometric target is not an achievable mean under arbitrary EH.
    % Report infeasibility; do not silently claim the constraint was met.
    [~,order]=sortrows([-rows(:,3),rows(:,4)],[1 2]); selected=order(1);
end
p.cycle=rows(selected,1)*ones(size(dev,1),1);
p.on_time=rows(selected,2)*ones(size(dev,1),1);
p.phase=floor(phases*rows(selected,1));
p.search.rows=rows; p.search.feasible=any(feasible);
p.search.selected=selected;
end
