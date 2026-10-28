function calibration = tune_information_detection(model,budget)
%TUNE_INFORMATION_DETECTION Tune information AND misses on independent data.
% J = information_per_actual_event/Psi - miss_weight*miss_fraction.
% All points and their Pareto status are saved. Published values never enter
% the objective. This finite transparent search is not paper's bayesopt code.
if nargin<1, model='paper'; end
if nargin<2, budget='quick'; end
base=information_detection_config(model,'quick');
base.make_plots=false; base.save_results=false; base.capture_trace=false; base.verbose=false;
base.rl.episodes=8; base.rl.steps=1600;
base.rl.validation_steps=2400; base.rl.validation_trials=1;
base.dt.data_episodes=6; base.dt.data_steps=1600;
base.dt.updates=200; base.dt.checkpoint_every=100;
base.dt.rollout_validation_steps=1600; base.dt.rollout_validation_trials=1;
counts=[50 250]; K=10000; repetitions=2;
if strcmp(budget,'extended')
    base.rl.episodes=50; base.rl.steps=10000;
    base.rl.validation_steps=10000; base.rl.validation_trials=5;
    base.dt.data_steps=10000; base.dt.data_episodes=12;
    base.dt.updates=1000; base.dt.checkpoint_every=250;
    base.dt.rollout_validation_steps=10000; base.dt.rollout_validation_trials=3;
    counts=[10 100 250]; K=10000; repetitions=5;
elseif ~strcmp(budget,'quick')
    error('Use quick or extended.');
end
folder=fullfile(fileparts(mfilename('fullpath')),['output_joint_calibration_' model]);
if ~exist(folder,'dir'), mkdir(folder); end
calibration.model=model; calibration.budget=budget; calibration.base=base;
calibration.selection_objective='I_per_actual_event/Psi - miss_weight*miss_fraction';
calibration.miss_weight=base.objective.miss_weight;
calibration.validation_N=counts; calibration.validation_steps=K;
calibration.validation_trials=repetitions;
calibration.row_columns={'method_1_RL_2_DT','candidate','N','information_actual',...
    'miss_fraction','objective','awake_budget','setup_seconds'};
calibration.rows=[];
% [group scale, energy margin, mu1, mu2, learned weight, energy weight, EH cap]
if strcmp(model,'archive_compatibility'), scale=4; else, scale=1; end
grid=[scale 2 10 5 .15 .25 1; 2*scale 2 20 5 .10 .50 1; scale 5 5 5 .25 .75 1];
if strcmp(model,'paper')
    % Guards still gate every command and real batteries gate execution.
    % Test whether a cap based only on MEAN EH is unnecessarily restrictive
    % when the finite test starts with a charged battery.
    grid(2:3,7)=0;
end
calibration.rl_grid=grid; best=-Inf; winner=base; winning_teachers={};
for candidate=1:size(grid,1)
    c=base; g=grid(candidate,:);
    c.rl.cluster_scale=g(1); c.rl.energy_margin=g(2); c.rl.mu1=g(3); c.rl.mu2=g(4);
    c.rl.learned_weight=g(5); c.rl.energy_weight=g(6);
    c.rl.cap_groups_to_energy=logical(g(7));
    [score,rows,policies]=assess(c,'rl',candidate,counts,K,repetitions,{});
    calibration.rows=[calibration.rows;rows]; %#ok<AGROW>
    if score>best
        best=score; winner=c; winning_teachers=policies; calibration.selected_rl=candidate;
    end
    fprintf('%s | joint RL candidate %d | J %.5f | I %.5f | miss %.3f%%\n',...
        model,candidate,score,mean(rows(:,4)),100*mean(rows(:,5))); fflush_if_octave();
    save(fullfile(folder,'calibration_checkpoint.mat'),'calibration','-v7');
end
calibration.rl_score=best; calibration.selected_rl_settings=winner.rl;
% [d_model context heads FFN Adam rate wake probability threshold RTG quantile]
architectures=[16 16 2 32 .001 .20 .75; 32 16 4 64 .001 .15 .90];
calibration.dt_grid=architectures; best=-Inf; selected=winner;
for candidate=1:size(architectures,1)
    c=winner; a=architectures(candidate,:);
    c.dt.cluster_scale=c.rl.cluster_scale; c.dt.energy_margin=c.rl.energy_margin;
    c.dt.cap_groups_to_energy=c.rl.cap_groups_to_energy;
    c.dt.learned_weight=c.rl.learned_weight; c.dt.energy_weight=c.rl.energy_weight;
    c.dt.d_model=a(1); c.dt.context=a(2); c.dt.heads=a(3); c.dt.ff_size=a(4);
    c.dt.learning_rate=a(5); c.dt.wake_threshold=a(6); c.dt.desired_return_quantile=a(7);
    [score,rows]=assess(c,'dt',candidate,counts,K,repetitions,winning_teachers);
    calibration.rows=[calibration.rows;rows]; %#ok<AGROW>
    if score>best, best=score; selected=c; calibration.selected_dt=candidate; end
    fprintf('%s | joint DT candidate %d | J %.5f | I %.5f | miss %.3f%%\n',...
        model,candidate,score,mean(rows(:,4)),100*mean(rows(:,5))); fflush_if_octave();
    save(fullfile(folder,'calibration_checkpoint.mat'),'calibration','-v7');
end
calibration.dt_score=best; calibration.selected_dt_settings=selected.dt;
calibration.selected_cfg=selected;
calibration.summary_columns={'method','candidate','mean_information','mean_miss','mean_objective','pareto'};
summary=[];
for method=1:2
    candidates=unique(calibration.rows(calibration.rows(:,1)==method,2));
    block=zeros(numel(candidates),6);
    for k=1:numel(candidates)
        rows=calibration.rows(calibration.rows(:,1)==method & calibration.rows(:,2)==candidates(k),:);
        block(k,:)=[method candidates(k) mean(rows(:,4:6),1) 0];
    end
    block(:,6)=pareto_information_detection(block(:,3),block(:,4)); summary=[summary;block]; %#ok<AGROW>
end
calibration.summary=summary;
save(fullfile(folder,'calibration.mat'),'calibration','-v7');
write_table(fullfile(folder,'calibration.csv'),calibration.row_columns,calibration.rows);
write_table(fullfile(folder,'pareto_summary.csv'),calibration.summary_columns,summary);
end

function [score,rows,policies]=assess(cfg,method,candidate,counts,K,repetitions,teachers)
rows=zeros(numel(counts),8); policies=cell(numel(counts),1);
for ni=1:numel(counts)
    N=counts(ni); seed=cfg.seed+5500000+ni*1000;
    rng(seed,'twister'); dev=PPP(cfg.A,cfg.B,N);
    [target,~]=voronoi_information_target(dev,cfg); teacher=[];
    if ~isempty(teachers), teacher=teachers{ni}; end
    clock=tic; policy=build_policy(method,dev,cfg,target,seed+100,teacher); setup=toc(clock);
    validation=cfg; validation.total=K; validation.burn_in=0;
    stats=zeros(repetitions,3);
    for t=1:repetitions
        scenario=make_scenario(validation,N,seed+900000+t,dev);
        m=simulate_network(validation,scenario,policy,false);
        stats(t,:)=[m.info_per_event m.misdetection information_detection_objective(m,cfg)];
    end
    rows(ni,:)=[1+strcmp(method,'dt') candidate N mean(stats,1) policy.control.awake_budget setup];
    policies{ni}=policy;
    fprintf('  %s candidate %d N=%d | I %.5f | miss %.3f%% | awake budget %d\n',...
        method,candidate,N,rows(ni,4),100*rows(ni,5),policy.control.awake_budget); fflush_if_octave();
end
score=mean(rows(:,6));
end

function write_table(path,columns,values)
fid=fopen(path,'w'); assert(fid>=0,'Cannot create tuning CSV.'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',columns{1}); fprintf(fid,',%s',columns{2:end}); fprintf(fid,'\n');
for k=1:size(values,1)
    fprintf(fid,'%.12g',values(k,1)); fprintf(fid,',%.12g',values(k,2:end)); fprintf(fid,'\n');
end
end

function fflush_if_octave()
if exist('OCTAVE_VERSION','builtin'), fflush(stdout); end
end
