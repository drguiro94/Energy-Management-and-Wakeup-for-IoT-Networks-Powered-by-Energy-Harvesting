function lookup = correlation_lookup(cfg)
%CORRELATION_LOOKUP Uniform-angle average of the sensing score in Eq. (15).
% A reported strength gives the reporter-to-event distance, but not bearing.
% The BS does not use the true event epicenter to choose additional devices.
lookup.r=linspace(0,cfg.active_distance,41);
lookup.gamma=linspace(0,hypot(cfg.A,cfg.B),161);
[G,R]=meshgrid(lookup.gamma,lookup.r); V=zeros(size(G));
angles=(0:cfg.angle_samples-1)*2*pi/cfg.angle_samples;
for angle=angles
    d=sqrt(max(0,R.^2+G.^2-2*R.*G*cos(angle)));
    contribution=exp(-cfg.eta*d);
    % Information is zero beyond the finite sensing range, Section II-A.
    contribution(d>cfg.active_distance)=0;
    V=V+contribution/numel(angles);
end
lookup.value=V;
end
