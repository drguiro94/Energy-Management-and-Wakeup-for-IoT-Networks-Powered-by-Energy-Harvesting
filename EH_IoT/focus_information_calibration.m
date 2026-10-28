function calibration = focus_information_calibration(model)
%FOCUS_INFORMATION_CALIBRATION Re-score measured candidates using info only.
% No simulated observation is modified. Only the derived selection score and
% selected settings are recomputed from recorded per-actual-event information.
root=fullfile(fileparts(mfilename('fullpath')),['output_calibration_' model]);
data=load(fullfile(root,'calibration.mat'),'calibration'); calibration=data.calibration;
previous_rl=calibration.selected_rl;
calibration.rows(:,8)=calibration.rows(:,5);
calibration.selection_objective='mean_information_per_actual_event';
for code=1:2
    choices=unique(calibration.rows(calibration.rows(:,1)==code,2));
    scores=zeros(size(choices));
    for k=1:numel(choices)
        selected=calibration.rows(:,1)==code & calibration.rows(:,2)==choices(k);
        scores(k)=mean(calibration.rows(selected,5));
    end
    [best,i]=max(scores);
    if code==1
        calibration.selected_rl=choices(i); calibration.rl_score=best;
    else
        calibration.selected_dt=choices(i); calibration.dt_score=best;
    end
end
assert(calibration.selected_rl==previous_rl,...
    'The RL winner changed: rerun DT candidate collection for the new sensing budget.');
cfg=calibration.base; g=calibration.rl_grid(calibration.selected_rl,:);
cfg.rl.cluster_scale=g(1); cfg.rl.energy_margin=g(2); cfg.rl.mu1=g(3);
cfg.rl.mu2=g(4); cfg.rl.learning_rate=g(5); cfg.rl.discount=g(6);
a=calibration.dt_grid(calibration.selected_dt,:);
cfg.dt.cluster_scale=cfg.rl.cluster_scale; cfg.dt.energy_margin=cfg.rl.energy_margin;
cfg.dt.d_model=a(1); cfg.dt.context=a(2); cfg.dt.heads=a(3); cfg.dt.ff_size=a(4);
cfg.dt.learning_rate=a(5); cfg.dt.updates=a(6); cfg.dt.wake_threshold=a(7);
cfg.dt.desired_return_quantile=a(8);
calibration.selected_cfg=cfg;
calibration.selected_rl_settings=cfg.rl; calibration.selected_dt_settings=cfg.dt;
save(fullfile(root,'calibration.mat'),'calibration','-v7');
fid=fopen(fullfile(root,'calibration.csv'),'w'); cleanup=onCleanup(@()fclose(fid));
for j=1:numel(calibration.row_columns)
    if j>1, fprintf(fid,','); end
    fprintf(fid,'%s',calibration.row_columns{j});
end
fprintf(fid,'\n');
for row=1:size(calibration.rows,1)
    fprintf(fid,'%.12g',calibration.rows(row,1));
    fprintf(fid,',%.12g',calibration.rows(row,2:end)); fprintf(fid,'\n');
end
fprintf('%s info-only selection: RL %d (%.4f), DT %d (%.4f).\n',...
    model,calibration.selected_rl,calibration.rl_score,calibration.selected_dt,calibration.dt_score);
end
