function s = make_scenario(cfg,N,seed,dev)
%MAKE_SCENARIO Exogenous randomness shared by every evaluated method.
% Training and tuning use different seeds. No event locations or true
% unreported sensing strengths are exposed to a practical policy.
rng(seed,'twister');
if nargin<4 || isempty(dev)
    if strcmp(cfg.deployment,'grid')
        dev = GridDeployment(cfg.A,cfg.B,N);
    else
        dev = PPP(cfg.A,cfg.B,N);
    end
end
s.dev = dev; K = cfg.total + cfg.burn_in;
s.event_occurs = rand(1,K) < cfg.alpha;
s.event_position = [cfg.A*rand(K,1),cfg.B*rand(K,1)];
if strcmp(cfg.harvest_model,'bernoulli_fixed')
    s.harvest = rand(N,K) < -expm1(-cfg.lambda*cfg.TTI);
else
    s.harvest = rand(N,K); % Archive: uniform [0, E_B] in every slot
end
if strcmp(cfg.detection_model,'bernoulli')
    s.detect_uniform = rand(N,K); % One observation per device per event
else
    s.detect_uniform = [];
end
if isnumeric(cfg.initial_battery)
    s.initial_battery = cfg.initial_battery*ones(N,1);
else
    s.initial_battery = cfg.E_max*rand(N,1);
end
end
