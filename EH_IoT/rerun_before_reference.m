%% OPTIONAL: REPEAT THE ARCHIVED V2 INFORMATION CHECK
% Run in a FRESH MATLAB/Octave session, to isolate the archived core functions.
% This is for auditing the paired before/after table, not the tuned experiment.
clear; clc;
root=fileparts(mfilename('fullpath'));
folder=fullfile(root,'output_reproduction_audit');
reference=fullfile(tempdir,'eh_iot_v2_reference');
if ~exist(reference,'dir'), mkdir(reference); end
unzip(fullfile(folder,'reference_v2_sources.zip'),reference);
addpath(reference,'-begin');
cleanup=onCleanup(@()rmpath(reference));
load(fullfile(folder,'paired_inputs.mat'),'oldcfg','counts','scenarios','policies');
fid=fopen(fullfile(folder,'before_paired_rerun.csv'),'w');
fprintf(fid,'N,method,information_actual,information_expected,miss_fraction,energy_actual\n');
for ni=1:numel(counts)
    for mi=1:2
        m=simulate_network(oldcfg,scenarios{ni},policies{mi,ni},false);
        fprintf(fid,'%d,%s,%.12g,%.12g,%.12g,%.12g\n',counts(ni),policies{mi,ni}.type,...
            m.info_per_event,m.info_per_expected_event,m.misdetection,m.energy_actual);
    end
end
fclose(fid);
clear cleanup;
