function calibration = calibrate_learning_parameters(base,options)
%CALIBRATE_LEARNING_PARAMETERS Broader, toolbox-free RL/DT calibration.
% All ten settings in the example's RL/DT blocks are varied, including
% episode/data budgets, learning rates, reward weights, context and updates.
% DT architecture, return quantile and wake threshold are also varied.
%
% This is a reproducible balanced search of FINITE candidate configurations,
% not exhaustive or Bayesian optimization and not a global-optimality claim.
% RL is selected first; DT candidates then use the winning frozen RL teacher.
% Each candidate sees common validation deployments/event/harvest streams.
% Final run_experiments streams are separate and never select candidates.
%
% First call: calibrates and saves. Later calls: reuse an IDENTICAL completed
% calibration or resume completed candidates. Changed options/source require
% another output_dir or options.force=true. A failed candidate gets -Inf;
% no failed deployment is silently omitted from its score.
if nargin<2, options=struct(); end
root=fileparts(mfilename('fullpath'));
o=defaults(base,options,root);
base.methods={'rl','dt'}; base.N_values=o.N_values; base.MCarlo=1;
base.total=o.validation_steps; base.burn_in=0; base.collect_learning=false;
base.save_results=false; base.save_learning_models=false;
base.make_plots=false; base.capture_trace=false; base.verbose=false;
base.resume=false; base.dt.save_dataset=false;
base.objective.miss_weight=o.miss_weight;
base.rl.reward_mode='information_detection';
base.rl.validation_metric='information_detection';
base.rl.validation_energy_weight=0;
base.rl.validation_steps=o.checkpoint_steps;
base.rl.validation_trials=o.checkpoint_trials;
base.rl.validation_every=10;
base.rl.patience=10;
base.dt.observable_feedback=true; base.dt.reuse_rl_teacher=true;
base.dt.rollout_selection=true;
base.dt.rollout_validation_steps=o.checkpoint_steps;
base.dt.rollout_validation_trials=o.checkpoint_trials;
base.dt.validation_every=25; base.dt.patience=20;
base.dt.checkpoint_every=250;
base.output_dir=o.output_dir;
validate_config(base);

% Build reproducible candidates. Every level of every searched field appears.
rl=make_candidates(base,'rl',o.rl_space,o.rl_candidates,o.seed+1);
dt=make_candidates(base,'dt',o.dt_space,o.dt_candidates,o.seed+2);
for k=1:numel(rl), validate_config(rl{k}); end
for k=1:numel(dt), validate_config(dt{k}); end
spec=o; spec=rmfield(spec,{'output_dir','force','plan_only'});
fixed=base;
drop={'output_dir','calibration','profile'};
for k=1:numel(drop)
    if isfield(fixed,drop{k}), fixed=rmfield(fixed,drop{k}); end
end
signature.schema=1; signature.options=spec; signature.base=fixed;
signature.sources=source_snapshot(root);

calibration.schema=1; calibration.status='planned';
calibration.model=o.model; calibration.options=o; calibration.signature=signature;
calibration.selection_objective='information_per_actual_event/Psi - miss_weight*miss_fraction';
calibration.rl_candidates=rl; calibration.dt_candidates=dt;
calibration.searched_rl=fieldnames(o.rl_space);
calibration.searched_dt=fieldnames(o.dt_space);
if o.plan_only, return; end

ensure_output_directory(o.output_dir);
complete_path=fullfile(o.output_dir,'calibration.mat');
checkpoint_path=fullfile(o.output_dir,'search_checkpoint.mat');
if ~o.force && exist(complete_path,'file')
    old=load(complete_path,'calibration');
    assert(isequaln(old.calibration.signature,signature), ...
        'Calibration differs. Use another calibration output_dir or force=true.');
    assert(strcmp(old.calibration.status,'complete'),'Calibration is not complete.');
    calibration=old.calibration;
    fprintf('Reusing completed parameter calibration: %s\n',complete_path);
    return;
end
if ~o.force && exist(checkpoint_path,'file')
    old=load(checkpoint_path,'calibration');
    assert(isequaln(old.calibration.signature,signature), ...
        'Search checkpoint differs. Use another calibration output_dir or force=true.');
    calibration=old.calibration;
    fprintf('Resuming completed calibration candidates.\n');
else
    if o.force
        % Preserve previous evidence before replacing it.
        backup=fullfile(o.output_dir,['backup_' datestr(now,'yyyymmdd_HHMMSS')]);
        if exist(complete_path,'file') || exist(checkpoint_path,'file')
            if exist(backup,'dir'), backup=tempname(o.output_dir); end
            ensure_output_directory(backup);
            files={'calibration.mat','search_checkpoint.mat','rl_candidates.csv', ...
                'dt_candidates.csv','validation_samples.csv','candidate_errors.txt'};
            for k=1:numel(files)
                src=fullfile(o.output_dir,files{k});
                if exist(src,'file'), copyfile(src,fullfile(backup,files{k})); end
            end
            % The replacement search must resume its new checkpoint, rather
            % than accidentally loading the old completed calibration.
            if exist(complete_path,'file'), delete(complete_path); end
            if exist(checkpoint_path,'file'), delete(checkpoint_path); end
        end
    end
    calibration.status='running';
    calibration.cases=make_cases(base,o);
    calibration.rl_completed=false(numel(rl),1);
    calibration.dt_completed=false(numel(dt),1);
    calibration.rl_scores=-Inf(numel(rl),1); calibration.dt_scores=-Inf(numel(dt),1);
    calibration.rl_rows=cell(numel(rl),1); calibration.dt_rows=cell(numel(dt),1);
    calibration.rl_errors=cell(numel(rl),1); calibration.dt_errors=cell(numel(dt),1);
    calibration.best_rl_score=-Inf; calibration.best_dt_score=-Inf;
    calibration.best_rl_teachers={};
    atomic_save(checkpoint_path,calibration);
end

for k=1:numel(calibration.rl_candidates)
    if calibration.rl_completed(k), continue; end
    c=calibration.rl_candidates{k};
    [score,rows,teachers,message]=assess(c,'rl',k,calibration.cases,o,{});
    calibration.rl_scores(k)=score; calibration.rl_rows{k}=rows;
    calibration.rl_errors{k}=message; calibration.rl_completed(k)=true;
    if score>calibration.best_rl_score
        calibration.best_rl_score=score;
        calibration.selected_rl=k; calibration.winning_rl_cfg=c;
        calibration.best_rl_teachers=teachers;
    end
    report_candidate('RL',k,score,message);
    atomic_save(checkpoint_path,calibration);
end
assert(isfinite(calibration.best_rl_score), ...
    'All RL candidates failed. Inspect candidate errors in search_checkpoint.mat.');

% Preserve selected RL settings while comparing the DT configurations.
for k=1:numel(calibration.dt_candidates)
    if calibration.dt_completed(k), continue; end
    c=calibration.dt_candidates{k};
    c.rl=calibration.winning_rl_cfg.rl;
    controls={'action_mode','cluster_scale','energy_guard','energy_margin', ...
        'cap_groups_to_energy','coverage_grid','learned_weight','energy_weight'};
    for j=1:numel(controls)
        if isfield(c.rl,controls{j}), c.dt.(controls{j})=c.rl.(controls{j}); end
    end
    calibration.dt_candidates{k}=c;
    [score,rows,~,message]=assess(c,'dt',k,calibration.cases,o,calibration.best_rl_teachers);
    calibration.dt_scores(k)=score; calibration.dt_rows{k}=rows;
    calibration.dt_errors{k}=message; calibration.dt_completed(k)=true;
    if score>calibration.best_dt_score
        calibration.best_dt_score=score;
        calibration.selected_dt=k; calibration.selected_cfg=c;
    end
    report_candidate('DT',k,score,message);
    atomic_save(checkpoint_path,calibration);
end
assert(isfinite(calibration.best_dt_score), ...
    ['All DT candidates failed. Inspect search_checkpoint.mat; sparse wake ' ...
     'decisions may require more offline data or different candidate settings.']);

% Restore experiment controls. No selected learning parameter is overwritten.
c=calibration.selected_cfg;
c.save_results=true; c.save_learning_models=true;
c.make_plots=true; c.capture_trace=true; c.verbose=true;
c.collect_learning=false; c.dt.observable_feedback=true; c.resume=false;
c.profile=['parameter_calibrated_' o.model];
c.calibration=struct('kind','balanced_parameter_search','model',o.model, ...
    'selected_rl',calibration.selected_rl,'selected_dt',calibration.selected_dt, ...
    'validation_N',o.N_values,'validation_deployments',o.deployments, ...
    'validation_steps',o.validation_steps,'validation_trials',o.validation_trials, ...
    'selection_objective',calibration.selection_objective, ...
    'searched_rl',{calibration.searched_rl},'searched_dt',{calibration.searched_dt});
calibration.selected_cfg=c;
calibration.status='complete';
calibration.row_columns={'candidate','N','deployment','information','miss_fraction', ...
    'objective','setup_seconds','awake_budget','event_count'};
calibration=rmfield(calibration,'best_rl_teachers');
write_outputs(calibration,o.output_dir);
atomic_save(complete_path,calibration);
fprintf('Calibration complete. RL candidate %d; DT candidate %d.\n', ...
    calibration.selected_rl,calibration.selected_dt);
end

function o=defaults(base,input,root)
o.model='custom';
o.output_dir=fullfile(root,'output_parameter_calibration');
o.N_values=[10 50 100 250]; o.deployments=2;
o.validation_steps=10000; o.validation_trials=2;
o.checkpoint_steps=10000; o.checkpoint_trials=3;
o.rl_candidates=12; o.dt_candidates=12;
o.seed=base.seed+100000000;
o.miss_weight=base.objective.miss_weight;
o.force=false; o.plan_only=false;
o.rl_space.episodes=[100 250];
o.rl_space.steps=[5000 10000];
o.rl_space.learning_rate=[1e-4 1e-3 1e-2];
o.rl_space.mu1=[1 5 10 20]; o.rl_space.mu2=[1 2 3 5];
o.dt_space.data_episodes=[8 12]; o.dt_space.data_steps=[5000 10000];
o.dt_space.context=[16 32 64 128]; o.dt_space.updates=[1000 2000];
o.dt_space.learning_rate=[1e-4 1e-3 1e-2];
% Rows: [embedding width, heads, feed-forward width].
o.dt_space.architecture=[16 2 32; 32 4 64; 64 4 128];
o.dt_space.wake_threshold=[0.15 0.20 0.30 0.40];
o.dt_space.desired_return_quantile=[0.75 0.90];
fields=fieldnames(input);
for k=1:numel(fields)
    assert(isfield(o,fields{k}),'Unknown calibration option: %s',fields{k});
    o.(fields{k})=input.(fields{k});
end
assert(all(o.N_values>=1 & o.N_values==floor(o.N_values)),'Invalid calibration N.');
positive={'deployments','validation_steps','validation_trials','checkpoint_steps', ...
    'checkpoint_trials','rl_candidates','dt_candidates'};
for k=1:numel(positive)
    v=o.(positive{k}); assert(isscalar(v) && v>=1 && v==floor(v),'Invalid %s.',positive{k});
end
assert(o.seed>=0 && o.seed==floor(o.seed),'Invalid calibration seed.');
assert(o.seed+1000000+numel(o.N_values)*o.deployments*2010000+o.validation_trials<2^32, ...
    'Calibration seed range exceeds the RNG limit.');
assert(o.validation_trials<10000,'Use fewer than 10000 validation trials.');
assert(isfinite(o.miss_weight) && o.miss_weight>=0,'Invalid missed-event weight.');
end

function list=make_candidates(base,method,space,count,seed)
% Anchor the first candidate at the recommended large-budget setting where
% that value belongs to the search space. Other candidates cover all levels.
rng(seed,'twister');
fields=fieldnames(space); list=repmat({base},count,1);
for f=1:numel(fields)
    name=fields{f}; values=space.(name);
    architecture=strcmp(name,'architecture');
    if architecture
        assert(size(values,2)==3,'Architecture rows must be [width heads FF].');
        assert(all(values(:,1)>0 & values(:,2)>0 & values(:,3)>0), ...
            'Invalid DT architecture.');
        assert(all(mod(values(:,1),values(:,2))==0),'Width must be divisible by heads.');
        levels=size(values,1);
        anchor=[base.dt.d_model base.dt.heads base.dt.ff_size];
        first=find(all(bsxfun(@eq,values,anchor),2),1);
    else
        assert(isnumeric(values) && isvector(values) && all(isfinite(values)) && ~isempty(values), ...
            'Invalid search levels for %s.',name);
        values=values(:)'; levels=numel(values);
        assert(isfield(base.(method),name),'Unknown %s search field: %s.',method,name);
        first=find(values==base.(method).(name),1);
    end
    assert(count>=levels,'Use at least %d %s candidates to cover %s.',levels,method,name);
    if isempty(first), first=1; end
    remaining=setdiff(1:levels,first); order=remaining;
    while numel(order)<count-1, order=[order 1:levels]; end %#ok<AGROW>
    order=order(1:count-1);
    if ~isempty(order), order=order(randperm(numel(order))); end
    indices=[first order];
    for k=1:count
        if architecture
            a=values(indices(k),:);
            list{k}.dt.d_model=a(1); list{k}.dt.heads=a(2); list{k}.dt.ff_size=a(3);
        else
            list{k}.(method).(name)=values(indices(k));
        end
    end
end
end

function cases=make_cases(base,o)
cases=cell(numel(o.N_values)*o.deployments,1); index=0;
for ni=1:numel(o.N_values)
    for deployment=1:o.deployments
        index=index+1; N=o.N_values(ni);
        item.N=N; item.deployment=deployment; item.geometry_seed=o.seed+index;
        rng(item.geometry_seed,'twister');
        if strcmp(base.deployment,'grid'), dev=GridDeployment(base.A,base.B,N);
        else, dev=PPP(base.A,base.B,N); end
        item.dev=dev;
        item.target=voronoi_information_target(dev,base);
        % Reserve a million seeds for each learner/case. Put outer validation
        % after every training block, including internal holdout rollouts.
        item.rl_training_seed=o.seed+1000000+(index-1)*2000000;
        item.dt_training_seed=item.rl_training_seed+1000000;
        item.validation_seeds=o.seed+1000000+numel(cases)*2000000+ ...
            index*10000+(1:o.validation_trials);
        cases{index}=item;
    end
end
end

function [score,rows,policies,message]=assess(cfg,method,candidate,cases,o,teachers)
rows=NaN(numel(cases),9); policies=cell(size(cases)); message='';
for j=1:numel(cases)
    item=cases{j}; rows(j,1:3)=[candidate item.N item.deployment];
end
for j=1:numel(cases)
    item=cases{j};
    try
        teacher=[]; seed=item.rl_training_seed;
        if strcmp(method,'dt'), seed=item.dt_training_seed; teacher=teachers{j}; end
        started=tic;
        policy=build_policy(method,item.dev,cfg,item.target,seed,teacher);
        setup=toc(started);
        c=cfg; c.total=o.validation_steps; c.capture_trace=false; c.collect_learning=false;
        values=zeros(o.validation_trials,4);
        for trial=1:o.validation_trials
            scenario=make_scenario(c,item.N,item.validation_seeds(trial),item.dev);
            % Passing by value keeps the teacher and selected policy frozen.
            metrics=simulate_network(c,scenario,policy,false);
            values(trial,:)=[metrics.info_per_event metrics.misdetection ...
                information_detection_objective(metrics,cfg) metrics.event_count];
        end
        if any(~isfinite(values(:))), error('Non-finite validation outcome.'); end
        rows(j,4:9)=[mean(values(:,1:3),1) setup ...
            policy.control.awake_budget sum(values(:,4))];
        policies{j}=policy;
    catch err
        score=-Inf;
        message=sprintf('N=%d deployment=%d: %s',item.N,item.deployment,err.message);
        return; % Reject the WHOLE candidate; never average only successful cases.
    end
end
score=mean(rows(:,6)); % Equal weight per N and independent deployment.
end

function sources=source_snapshot(root)
% Cache compatibility includes the actual algorithm sources, not just options.
files={'calibrate_learning_parameters.m','paper_config.m','tuned_config.m', ...
    'recommended_config.m','information_detection_config.m', ...
    'recommended_information_detection_config.m','build_policy.m','make_scenario.m', ...
    'simulate_network.m','train_two_stage_rl.m','shared_q_update.m','q_state.m', ...
    'train_decision_transformer.m','train_dt_stage.m','dt_prepare_trajectory.m', ...
    'dt_sequence_window.m','dt_initialize.m','dt_forward.m','dt_loss_gradient.m', ...
    'dt_adam_update.m','dt_control.m','dt_feedback.m','select_dt_rollout_checkpoint.m', ...
    'configure_learning_control.m','learning_idle_actions.m','learning_observation.m', ...
    'idle_task_reward.m','validation_objective.m','information_detection_objective.m', ...
    'PPP.m','GridDeployment.m','kmeans_cluster.m','voronoi_information_target.m', ...
    'wake_close_device.m','correlation_lookup.m','check_active.m', ...
    'update_battery_active.m','update_battery_harvest.m','aggregate_information.m'};
sources=cell(numel(files),2);
for k=1:numel(files)
    sources{k,1}=files{k}; sources{k,2}=fileread(fullfile(root,files{k}));
end
end

function atomic_save(path,calibration)
temporary=[path '.partial.mat'];
save(temporary,'calibration','-v7');
[ok,message]=movefile(temporary,path,'f');
assert(ok,'Cannot save calibration: %s',message);
end

function report_candidate(method,k,score,message)
fprintf('%s candidate %d | validation objective %.6g\n',method,k,score);
if ~isempty(message), fprintf('  Candidate rejected: %s\n',message); end
if exist('OCTAVE_VERSION','builtin'), fflush(stdout); end
end

function write_outputs(c,folder)
for kind={'rl','dt'}
    method=kind{1}; configs=c.([method '_candidates']);
    rows=c.([method '_rows']); scores=c.([method '_scores']);
    if strcmp(method,'rl')
        fields={'episodes','steps','learning_rate','mu1','mu2'};
    else
        fields={'data_episodes','data_steps','context','updates','learning_rate', ...
            'd_model','heads','ff_size','wake_threshold','desired_return_quantile'};
    end
    data=NaN(numel(configs),numel(fields)+6);
    for k=1:numel(configs)
        parameters=configs{k}.(method);
        data(k,1)=k;
        for j=1:numel(fields), data(k,j+1)=parameters.(fields{j}); end
        if isfinite(scores(k)), data(k,end-4:end-3)=mean(rows{k}(:,4:5),1); end
        data(k,end-2)=scores(k); data(k,end)=isfinite(scores(k));
    end
    valid=isfinite(scores);
    data(valid,end-1)=pareto_information_detection(data(valid,end-4),data(valid,end-3));
    data(~valid,end-1)=0;
    header=[{'candidate'} fields {'information','miss_fraction','objective','pareto','success'}];
    numeric_csv(fullfile(folder,[method '_candidates.csv']),header,data);
end
data=[];
for method=1:2
    if method==1, blocks=c.rl_rows; else, blocks=c.dt_rows; end
    for k=1:numel(blocks)
        data=[data;method*ones(size(blocks{k},1),1) blocks{k}]; %#ok<AGROW>
    end
end
numeric_csv(fullfile(folder,'validation_samples.csv'),[{'method_1_RL_2_DT'} c.row_columns],data);
fid=fopen(fullfile(folder,'candidate_errors.txt'),'w');
assert(fid>=0,'Cannot create candidate error log.'); cleanup=onCleanup(@()fclose(fid));
for method={'rl','dt'}
    messages=c.([method{1} '_errors']);
    for k=1:numel(messages)
        if ~isempty(messages{k}), fprintf(fid,'%s candidate %d: %s\n',method{1},k,messages{k}); end
    end
end
end

function numeric_csv(path,columns,values)
fid=fopen(path,'w'); assert(fid>=0,'Cannot create %s.',path);
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',columns{1}); fprintf(fid,',%s',columns{2:end}); fprintf(fid,'\n');
for k=1:size(values,1)
    fprintf(fid,'%.12g',values(k,1)); fprintf(fid,',%.12g',values(k,2:end)); fprintf(fid,'\n');
end
end

