function Results = run_experiments(cfg)
%RUN_EXPERIMENTS Independent Monte Carlo trials with common random inputs.
% Every method sees the same deployment, initial charge, event stream, and
% EH realizations within a trial. Only policy training/tuning uses new data.
validate_config(cfg);
if cfg.save_results, ensure_output_directory(cfg.output_dir); end
names=metric_names(); P=numel(cfg.methods); Q=numel(cfg.N_values);
Results.cfg=cfg; Results.methods=cfg.methods; Results.labels=cfg.methods;
Results.N=cfg.N_values; Results.completed=false(cfg.MCarlo,Q);
Results.policy=cell(P,Q); Results.example=struct();
for f=1:numel(names), Results.raw.(names{f})=NaN(cfg.MCarlo,P,Q); end
checkpoint=fullfile(cfg.output_dir,'checkpoint.mat');
if cfg.resume && exist(checkpoint,'file')
    previous=load(checkpoint,'Results'); a=previous.Results.cfg; b=cfg;
    % These settings change I/O, not the stochastic experiment.
    ignore={'resume','verbose','make_plots','figure_visible','figure_formats','checkpoint_every'};
    for j=1:numel(ignore)
        a=rmfield(a,ignore{j}); b=rmfield(b,ignore{j});
    end
    assert(isequaln(a,b),'Checkpoint parameters differ from this run. Use a new output_dir.');
    Results=previous.Results; Results.cfg=cfg;
end
for ni=1:Q
    N=cfg.N_values(ni);
    for rep=1:cfg.MCarlo
        if Results.completed(rep,ni), continue; end
        seed=cfg.seed+ni*10000+rep;
        scenario=make_scenario(cfg,N,seed);
        % Voronoi geometry belongs to the deployment, not to any one policy.
        [target,d_star,cells]=voronoi_information_target(scenario.dev,cfg);
        teacher=[];
        for mi=1:P
            t=tic;
            policy=build_policy(cfg.methods{mi},scenario.dev,cfg,target,...
                cfg.seed+1000000+ni*10000+rep*100+mi,teacher);
            if strcmp(policy.type,'rl') && isfield(cfg.dt,'reuse_rl_teacher') && cfg.dt.reuse_rl_teacher
                teacher=policy;
            end
            setup_seconds=toc(t);
            if cfg.save_results && any(strcmp(policy.type,{'rl','dt'})) && cfg.save_learning_models
                model_dir=fullfile(cfg.output_dir,'models');
                ensure_output_directory(model_dir);
                save(fullfile(model_dir,sprintf('%s_N%d_trial%d.mat',policy.type,N,rep)),...
                    'policy','cfg','-v7');
            end
            eval_cfg=cfg;
            eval_cfg.capture_trace=cfg.capture_trace && rep==1 && ...
                ni==min(Q,2) && strcmp(cfg.methods{mi},'cluster');
            [m,trace]=simulate_network(eval_cfg,scenario,policy,false);
            for f=1:numel(names), Results.raw.(names{f})(rep,mi,ni)=m.(names{f}); end
            if ~isfield(Results.raw,'setup_seconds'), Results.raw.setup_seconds=NaN(cfg.MCarlo,P,Q); end
            Results.raw.setup_seconds(rep,mi,ni)=setup_seconds;
            Results.labels{mi}=policy.label;
            if rep==1
                Results.policy{mi,ni}=policy;
                if eval_cfg.capture_trace
                    Results.example.trace=trace; Results.example.policy=policy;
                    Results.example.cells=cells; Results.example.d_star=d_star;
                    Results.example.target=target; Results.example.N=N;
                end
            end
        end
        Results.completed(rep,ni)=true;
        if cfg.verbose && (rep==1 || mod(rep,cfg.checkpoint_every)==0 || rep==cfg.MCarlo)
            fprintf('N=%3d | deployment %d/%d | energy balance error <= %.3g\n',...
                N,rep,cfg.MCarlo,max(Results.raw.budget_error(rep,:,ni)));
        end
        if cfg.save_results && mod(rep,cfg.checkpoint_every)==0
            save_checkpoint(checkpoint,Results);
        end
    end
    if cfg.save_results, save_checkpoint(checkpoint,Results); end
end
names=fieldnames(Results.raw);
for f=1:numel(names)
    for mi=1:P
        for ni=1:Q
            [mu,half,n]=mean_ci95(Results.raw.(names{f})(:,mi,ni));
            Results.mean.(names{f})(mi,ni)=mu;
            Results.ci95.(names{f})(mi,ni)=half;
            Results.count.(names{f})(mi,ni)=n;
        end
    end
end
Results.legacy_row_names={'info_per_event','misdetection','low_energy','mean_battery',...
    'idle_energy','tx_energy','sleep_energy','wrong_per_event'};
Results.legacy=cell(P,1); % Similar row-oriented arrays to Results_std/kmean.
for mi=1:P
    matrix=zeros(numel(Results.legacy_row_names),Q);
    for j=1:size(matrix,1), matrix(j,:)=Results.mean.(Results.legacy_row_names{j})(mi,:); end
    Results.legacy{mi}=matrix;
end
if cfg.save_results
    save(fullfile(cfg.output_dir,'results.mat'),'Results','-v7');
    write_results_csv(Results);
    save_checkpoint(checkpoint,Results);
end
end

function save_checkpoint(path,Results)
temporary=[path '.partial.mat'];
save(temporary,'Results','-v7');
movefile(temporary,path,'f');
end
