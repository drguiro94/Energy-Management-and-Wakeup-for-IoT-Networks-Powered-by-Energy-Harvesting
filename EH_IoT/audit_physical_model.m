function audit = audit_physical_model(cfg,counts,deployments,events_per_deployment)
%AUDIT_PHYSICAL_MODEL Algorithm-independent information and energy limits.
% The disk-area bound applies to ANY N-point placement under uniform events
% and max aggregation. The MC ideal additionally assumes uniform random IoTDs.
if nargin<2, counts=[10 100 250]; end
if nargin<3, deployments=160; end
if nargin<4, events_per_deployment=1600; end
assert(strcmp(cfg.aggregation,'max'),'This information bound assumes max aggregation.');
audit.cfg=cfg; audit.rows=zeros(numel(counts),4);
for ni=1:numel(counts)
    N=counts(ni); R=sqrt(cfg.A*cfg.B/(pi*N)); reach=min(R,cfg.active_distance);
    if cfg.eta==0
        bound=cfg.Psi*(reach/R)^2;
    else
        z=cfg.eta*reach;
        bound=cfg.Psi*2*(-expm1(-z)-z*exp(-z))/(cfg.eta^2*R^2);
    end
    values=zeros(deployments,1);
    for rep=1:deployments
        rng(cfg.seed+8000000+ni*1000+rep,'twister');
        dev=PPP(cfg.A,cfg.B,N);
        points=PPP(cfg.A,cfg.B,events_per_deployment);
        distance_squared=bsxfun(@plus,sum(points.^2,2),sum(dev.^2,2)')-2*points*dev';
        nearest=sqrt(max(0,min(distance_squared,[],2)));
        information=cfg.Psi*exp(-cfg.eta*nearest);
        information(nearest>cfg.active_distance)=0;
        values(rep)=mean(information);
    end
    [mu,half]=mean_ci95(values);
    audit.rows(ni,:)=[N mu half bound];
end
if strcmp(cfg.harvest_model,'bernoulli_fixed')
    audit.mean_raw_harvest=cfg.E_B*(-expm1(-cfg.lambda*cfg.TTI));
else
    audit.mean_raw_harvest=cfg.E_B/2;
end
if isnumeric(cfg.initial_battery), initial=cfg.initial_battery; else, initial=cfg.E_max/2; end
audit.energy_drain_bound=audit.mean_raw_harvest+initial/cfg.total;
audit.columns={'N','uniform_deployment_ideal_mean','ci95_half','any_placement_disk_bound'};
end
