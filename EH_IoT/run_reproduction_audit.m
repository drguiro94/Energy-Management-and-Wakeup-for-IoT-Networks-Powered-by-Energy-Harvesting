%% CHECK PHYSICAL LIMITS BEFORE TRYING TO MATCH A PUBLISHED PLOT
clear; clc;
addpath(fileparts(mfilename('fullpath')));
folder=fullfile(fileparts(mfilename('fullpath')),'output_reproduction_audit');
if ~exist(folder,'dir'), mkdir(folder); end
profiles={'paper','archive_compatibility'}; audits=cell(2,1);
fid=fopen(fullfile(folder,'physical_bounds.csv'),'w');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'profile,N,ideal_mean,ci95_half,placement_upper_bound,mean_harvest,drain_bound_10000_TTI\n');
for p=1:2
    cfg=tuned_config(profiles{p}); cfg.total=10000;
    audits{p}=audit_physical_model(cfg);
    for row=1:size(audits{p}.rows,1)
        r=audits{p}.rows(row,:);
        fprintf(fid,'%s,%d,%.12g,%.12g,%.12g,%.12g,%.12g\n',profiles{p},r,...
            audits{p}.mean_raw_harvest,audits{p}.energy_drain_bound);
    end
    fprintf('%s: N=250 random-deployment ideal %.4f; any-placement bound %.4f\n',...
        profiles{p},audits{p}.rows(end,2),audits{p}.rows(end,4));
end
save(fullfile(folder,'physical_bounds.mat'),'audits','-v7');
