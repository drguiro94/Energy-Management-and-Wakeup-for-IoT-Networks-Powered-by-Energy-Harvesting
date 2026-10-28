function calibration = tune_rl_dt(model,budget)
%TUNE_RL_DT Actual hyperparameter search using independent validation streams.
% Published figure values are NOT optimization targets. Candidate selection
% maximizes delivered information PER ACTUAL EVENT, without an energy term.
% Training, checkpoint validation, calibration validation, and final tests
% have disjoint seeds. Both physical profiles are labeled in the saved files.
if nargin<1, model='paper'; end
if nargin<2, budget='quick'; end
base=tuned_config(model,'quick'); base.capture_trace=false;
base.make_plots=false; base.save_results=false; base.verbose=false;
base.rl.episodes=8; base.rl.steps=800;
base.rl.validation_steps=800; base.rl.validation_trials=2;
base.dt.data_steps=800; base.dt.data_episodes=6;
base.dt.validation_windows=16; base.dt.save_dataset=false;
counts=[50 250]; validation_steps=1500; validation_trials=2;
if strcmp(budget,'extended')
    base.rl.episodes=50; base.rl.steps=10000;
    base.rl.validation_steps=10000; base.rl.validation_trials=5;
    base.dt.data_steps=10000; base.dt.data_episodes=12;
    counts=[10 100 250]; validation_steps=10000; validation_trials=5;
elseif ~strcmp(budget,'quick')
    error('Use quick or extended.');
end
folder=fullfile(fileparts(mfilename('fullpath')),['output_calibration_' model]);
if ~exist(folder,'dir'), mkdir(folder); end
calibration.model=model; calibration.budget=budget;
calibration.validation_N=counts; calibration.validation_steps=validation_steps;
calibration.validation_trials=validation_trials; calibration.base=base;
calibration.selection_objective='mean_information_per_actual_event';
calibration.rows=[];
% [spatial group multiplier, energy margin, mu1, mu2, Q rate, discount]
grid=[0.5 2 10 1 .01 .95; 1 2 20 3 .01 .95;...
      2 2 20 5 .005 .99; 4 5 5 5 .01 .95];
calibration.rl_grid=grid;
best=-Inf; winner=base;
for candidate=1:size(grid,1)
    cfg=base; g=grid(candidate,:);
    cfg.rl.cluster_scale=g(1); cfg.rl.energy_margin=g(2);
    cfg.rl.mu1=g(3); cfg.rl.mu2=g(4); cfg.rl.learning_rate=g(5); cfg.rl.discount=g(6);
    [score,rows]=assess(cfg,'rl',candidate,counts,validation_steps,validation_trials);
    calibration.rows=[calibration.rows;rows]; %#ok<AGROW>
    if score>best, best=score; winner=cfg; calibration.selected_rl=candidate; end
    fprintf('%s | RL candidate %d/%d | calibration score %.5f\n',model,candidate,size(grid,1),score);
    save(fullfile(folder,'calibration_checkpoint.mat'),'calibration','-v7');
end
calibration.rl_score=best; calibration.selected_rl_settings=winner.rl;
% Same sensing budget as the selected RL controller; compare representation,
% context, learning rate, and calibrated wake threshold without imposing ranks.
architectures=[16 16 2 32 .001 200 .30 .75; 32 32 4 64 .0005 300 .25 .50];
if strcmp(budget,'extended'), architectures(:,6)=2000; end
calibration.dt_grid=architectures; best=-Inf; selected=winner;
for candidate=1:size(architectures,1)
    cfg=winner; a=architectures(candidate,:);
    cfg.dt.cluster_scale=cfg.rl.cluster_scale; cfg.dt.energy_margin=cfg.rl.energy_margin;
    cfg.dt.d_model=a(1); cfg.dt.context=a(2); cfg.dt.heads=a(3); cfg.dt.ff_size=a(4);
    cfg.dt.learning_rate=a(5); cfg.dt.updates=a(6);
    cfg.dt.wake_threshold=a(7); cfg.dt.desired_return_quantile=a(8);
    [score,rows]=assess(cfg,'dt',candidate,counts,validation_steps,validation_trials);
    calibration.rows=[calibration.rows;rows]; %#ok<AGROW>
    if score>best, best=score; selected=cfg; calibration.selected_dt=candidate; end
    fprintf('%s | DT candidate %d/%d | calibration score %.5f\n',model,candidate,size(architectures,1),score);
    save(fullfile(folder,'calibration_checkpoint.mat'),'calibration','-v7');
end
calibration.dt_score=best; calibration.selected_dt_settings=selected.dt;
calibration.selected_cfg=selected;
calibration.row_columns={'method_code_1_RL_2_DT','candidate','N','information_expected',...
    'information_actual','miss_fraction','energy_actual','score','spatial_groups','setup_seconds'};
save(fullfile(folder,'calibration.mat'),'calibration','-v7');
write_calibration(fullfile(folder,'calibration.csv'),calibration);
end

function [score,rows]=assess(cfg,method,candidate,counts,K,repetitions)
rows=zeros(numel(counts),10);
for ni=1:numel(counts)
    N=counts(ni); seed=cfg.seed+3000000+ni*1000;
    rng(seed,'twister'); dev=PPP(cfg.A,cfg.B,N);
    [target,~]=voronoi_information_target(dev,cfg);
    t=tic; policy=build_policy(method,dev,cfg,target,seed+100); setup=toc(t);
    validation=cfg; validation.total=K; validation.burn_in=0;
    stats=zeros(repetitions,4);
    for trial=1:repetitions
        scenario=make_scenario(validation,N,seed+400000+trial,dev);
        m=simulate_network(validation,scenario,policy,false);
        stats(trial,:)=[m.info_per_expected_event m.info_per_event m.misdetection m.energy_actual];
    end
    average=mean(stats,1);
    objective=average(2);
    code=1+strcmp(method,'dt');
    rows(ni,:)=[code candidate N average objective numel(unique(policy.control.groups)) setup];
end
score=mean(rows(:,8));
end

function write_calibration(path,c)
fid=fopen(path,'w'); assert(fid>=0,'Cannot create calibration CSV.');
cleanup=onCleanup(@()fclose(fid));
for j=1:numel(c.row_columns)
    if j>1, fprintf(fid,','); end
    fprintf(fid,'%s',c.row_columns{j});
end
fprintf(fid,'\n');
for row=1:size(c.rows,1)
    fprintf(fid,'%.12g',c.rows(row,1));
    fprintf(fid,',%.12g',c.rows(row,2:end)); fprintf(fid,'\n');
end
end
