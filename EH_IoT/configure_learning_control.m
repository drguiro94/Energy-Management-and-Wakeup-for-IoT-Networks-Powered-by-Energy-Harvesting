function policy = configure_learning_control(policy,dev,cfg,method)
%CONFIGURE_LEARNING_CONTROL Explicit feasible action set for learned policies.
% The paper mentions cluster-based sensing control (Appendix B). This optional
% cluster_rank selects one energy-eligible sensor per spatial group.
% coverage_rank uses that total sensing budget for global greedy area cover,
% with learned and energy preferences. Neither uses true sleeping-device
% batteries, the current unseen event, or future harvesting samples.
if strcmp(method,'dt'), options=cfg.dt; else, options=cfg.rl; end
policy.control.mode=options.action_mode;
policy.control.energy_guard=options.energy_guard;
policy.control.minimum_energy=cfg.Tx_E+cfg.idle_E+options.energy_margin;
policy.control.groups=[]; policy.control.phase=[]; policy.control.cycle=[];
if any(strcmp(options.action_mode,{'cluster_rank','coverage_rank'}))
    count=ceil(options.cluster_scale*cfg.A*cfg.B/(pi*cfg.active_distance^2));
    if options.cap_groups_to_energy
        if strcmp(cfg.harvest_model,'bernoulli_fixed'), mean_h=cfg.E_B*(-expm1(-cfg.lambda*cfg.TTI));
        else, mean_h=cfg.E_B/2; end
        awake_extra=cfg.idle_E-cfg.wake_up_Energy+...
            cfg.alpha*cfg.Tx_E*min(1,pi*cfg.active_distance^2/(cfg.A*cfg.B));
        energy_count=max(1,floor(size(dev,1)*max(0,mean_h-cfg.wake_up_Energy)/awake_extra));
        count=min(count,energy_count);
    end
    [groups,cent,~,cycle,phase]=kmeans_cluster(dev,cfg,count);
    policy.control.groups=groups; policy.control.phase=phase; policy.control.cycle=cycle;
    policy.cluster_idx=groups; policy.centroids=cent;
    if strcmp(options.action_mode,'coverage_rank')
        % Fixed quadrature of the known monitored area. No event locations
        % or hidden battery samples are used to coordinate the awake set.
        q=options.coverage_grid;
        [x,y]=meshgrid(((1:q)-0.5)*cfg.A/q,((1:q)-0.5)*cfg.B/q);
        points=[x(:) y(:)];
        distances=bsxfun(@minus,dev(:,1),points(:,1)').^2+...
            bsxfun(@minus,dev(:,2),points(:,2)').^2;
        policy.control.coverage=double(distances<=cfg.active_distance^2);
        policy.control.awake_budget=numel(unique(groups));
        policy.control.learned_weight=options.learned_weight;
        policy.control.energy_weight=options.energy_weight;
        policy.control.maximum_energy=cfg.E_max;
    end
end
end
