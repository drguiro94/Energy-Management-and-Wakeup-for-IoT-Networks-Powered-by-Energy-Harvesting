function run_validation()
%RUN_VALIDATION Model invariants, limiting cases, and reproducible experiments.
% These checks validate mechanics, not numerical agreement with the paper.
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.make_plots=false; cfg.save_results=false;
cfg.capture_trace=false; cfg.verbose=false;
cfg.N_values=12; cfg.MCarlo=2; cfg.total=120;
cfg.search_total=60; cfg.search_MCarlo=1;
validate_config(cfg);

%% ON timing and one scheduled device per nonempty cluster per slot.
for L=[2 4 8]
    for ell=1:2
        count=0;
        for k=1:8*L
            count=count+check_idle(k,L,ell,0,100,cfg);
        end
        assert(count==8*ell,'Duty-cycle phase does not advance correctly.');
    end
end
rng(7,'twister'); dev=PPP(cfg.A,cfg.B,24);
[idx,~,~,L,phase]=kmeans_cluster(dev,cfg);
for k=1:50
    on=check_idle(k,L,ones(24,1),phase,100*ones(24,1),cfg);
    for group=unique(idx)'
        assert(sum(on(idx==group))==1,'Cluster does not have exactly one ON slot.');
    end
end

%% Centered grid has the exact covering distance in Eq. (22).
grid=GridDeployment(20,20,4);
[target,dstar,cells]=voronoi_information_target(grid,cfg);
assert(abs(dstar-sqrt(400/(2*4)))<1e-9,'Incorrect bounded Voronoi radius.');
assert(abs(target-exp(-dstar))<1e-12,'Incorrect information target.');
for j=1:4
    assert(all(cells{j}(:)>=-1e-9) && all(cells{j}(:)<=20+1e-9));
end

%% Fixed EH quanta and the correct Poisson-slot arrival probability.
rng(11,'twister'); prob=-expm1(-cfg.lambda*cfg.TTI);
H=EH_random(200000,prob,cfg.E_B);
assert(all(H==0 | H==cfg.E_B),'EH quantum is not fixed.');
assert(abs(mean(H)-prob*cfg.E_B)<0.003,'EH arrivals have the wrong mean.');

%% Insufficient energy, capacity clipping, and energy conservation.
[b,paid,spill]=update_battery_harvest([0;99;8],[1;0;10],[1;5;0],cfg);
assert(isequal(b,[1;100;0]) && isequal(paid,[0;0;8]) && isequal(spill,[0;4;0]));
[ok,b,paid]=update_battery_active([9;10;20],[1;1;0],cfg);
assert(isequal(ok,[false;true;false]) && isequal(b,[0;0;20]) && isequal(paid,[9;10;0]));

%% Report strength and the alternative probabilistic sensing interpretation.
[on,info]=check_active([0 0;1 0;5 0],[0 0],4,true(3,1),cfg,zeros(3,1));
assert(isequal(on,[true;true;false]) && abs(info(2)-exp(-1))<1e-12);
stochastic=cfg; stochastic.detection_model='bernoulli'; rng(17,'twister');
[on,~]=check_active([ones(40000,1) zeros(40000,1)],[0 0],4,true(40000,1),stochastic,rand(40000,1));
assert(abs(mean(on)-exp(-1))<0.015);

%% Stochastic Markov matrix and spend-then-harvest boundary behavior.
[R,levels]=battery_transition_matrix(cfg,[1 11],[0.8 0.2],1);
assert(max(abs(full(sum(R,2))-1))<1e-12 && all(nonzeros(R)>=0));
assert(abs(full(R(1,2))-prob)<1e-12 && levels(end)==cfg.E_max);
[onecost,~]=battery_transition_matrix(cfg,1,1,1);
stationary=zeros(size(onecost,1),1); stationary(end)=1;
for it=1:300, stationary=onecost'*stationary; end
assert(abs(stationary(2)-prob)<1e-9 && sum(stationary(3:end))<1e-9,...
    'Constant unit-cost chain disagrees with its exact two-state limit.');

%% One-slot physical limit: idle cost leaves insufficient energy for Tx.
one=cfg; one.N_values=1; one.MCarlo=1; one.total=1; one.alpha=1;
one.lambda=0; one.initial_battery=10;
single=make_scenario(one,1,1,[0 0]);
single.event_position=[0 0]; single.event_occurs=true; single.harvest=false;
p.type='random'; p.cycle=1; p.on_time=1; p.phase=0; p.target=0;
p.lookup=correlation_lookup(one);
lim=simulate_network(one,single,p,false);
assert(lim.info_per_event==0 && lim.misdetection==1 && lim.energy_actual==10);
assert(lim.energy_requested==11 && lim.final_battery==0);

%% The journal's three aggregate-information choices are intentionally distinct.
agg=cfg; agg.aggregation='max'; assert(aggregate_information([0.7;0.6],agg)==0.7);
agg.aggregation='sum_saturated'; assert(aggregate_information([0.7;0.6],agg)==1);
agg.aggregation='sum'; assert(abs(aggregate_information([0.7;0.6],agg)-1.3)<1e-12);

%% Wake ordering excludes previous devices and depends on reports only.
lookup=correlation_lookup(cfg);
D=[0 .2 6;.2 0 5.8;6 5.8 0];
[order,~]=wake_close_device(D,[exp(-0.2);0;0],[true;false;false],cfg,lookup);
assert(~isempty(order) && order(1)==2 && ~any(order==1));
[order,~]=wake_close_device(D,zeros(3,1),false(3,1),cfg,lookup);
assert(isempty(order),'Wakeups were selected without an initial report.');

%% Complete common-input experiment and reproducibility.
A=run_experiments(cfg); B=run_experiments(cfg);
assert(isequaln(A.raw.info_per_event,B.raw.info_per_event),'Seeds are not reproducible.');
assert(max(A.raw.budget_error(:))<1e-7,'Network violates energy conservation.');
assert(max(abs(A.raw.net_stored(:)-A.raw.battery_change(:)))<1e-9);
assert(all(A.raw.energy_actual(:)<=A.raw.energy_requested(:)+1e-10));
assert(all(A.raw.info_per_event(:)>=0 & A.raw.info_per_event(:)<=1));
for mi=2:numel(cfg.methods)
    assert(isequal(A.raw.event_count(:,1,:),A.raw.event_count(:,mi,:)));
end

%% No events produces explicit NaN event statistics, never an Inf or crash.
none=cfg; none.alpha=0; none.methods={'random'};
Z=run_experiments(none);
assert(all(isnan(Z.raw.info_per_event(:))) && all(Z.raw.event_count(:)==0));

%% Both alternate model modes run end to end under the same invariants.
alt=cfg; alt.detection_model='bernoulli'; alt.methods={'cluster','genie'};
T=run_experiments(alt);
assert(max(T.raw.budget_error(:))<1e-7 && all(T.raw.info_per_event(:)<=1));
archive=paper_config('archive'); archive.make_plots=false; archive.save_results=false;
archive.capture_trace=false; archive.verbose=false; archive.N_values=10;
archive.total=80; archive.MCarlo=1; archive.search_total=40; archive.search_MCarlo=1;
T=run_experiments(archive);
assert(max(T.raw.budget_error(:))<1e-7);

%% Reference Q-learning actually trains and runs, with bounded shared states.
qcfg=cfg; qcfg.N_values=10; qcfg.MCarlo=1; qcfg.total=80;
qcfg.methods={'q_reference'}; qcfg.rl.episodes=2; qcfg.rl.steps=80;
Q=run_experiments(qcfg);
assert(all(isfinite(Q.policy{1}.q(:))) && any(Q.policy{1}.q(:,1)~=0));
assert(Q.raw.budget_error<1e-7);
[~,half,n]=mean_ci95([1 2 3]);
assert(n==3 && abs(half-4.302652729/sqrt(3))<1e-6);
fprintf('All model validation checks passed.\n');
end
