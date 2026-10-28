%% RE-SIMULATE EVENT-PROBABILITY SENSITIVITY -- FIG. 15 METRIC FAMILIES
% Envelopes cover ONLY the practical policies available in this package.
clear; clc; close all;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick'); cfg.N_values=[10 250];
cfg.methods={'random','adjusted','cluster'};
cfg.capture_trace=false; cfg.make_plots=false;
alphas=[0.01 0.03 0.1 0.3 1];
root=fullfile(fileparts(mfilename('fullpath')),'output_sensitivity');
series=cell(size(alphas));
for i=1:numel(alphas)
    cfg.alpha=alphas(i); cfg.output_dir=fullfile(root,sprintf('alpha_%g',alphas(i)));
    series{i}=run_experiments(cfg);
end
cfg.output_dir=root; cfg.make_plots=true;
save(fullfile(root,'sensitivity.mat'),'series','alphas','-v7');
fig=figure('Visible',cfg.figure_visible,'Position',[100 100 800 700]);
colors=[0.8 0.2 0.2; 0.15 0.55 0.25];
fields={'info_per_expected_event','energy_actual'};
labels={'Information per expected event','Actual energy / IoTD / TTI'};
for f=1:2
    subplot(2,1,f); hold on;
    for ni=1:numel(cfg.N_values)
        low=zeros(size(alphas)); high=low;
        for i=1:numel(alphas)
            values=series{i}.mean.(fields{f})(:,ni);
            low(i)=min(values); high(i)=max(values);
        end
        fill([alphas fliplr(alphas)],[low fliplr(high)],...
            0.75+0.25*colors(ni,:),'EdgeColor',colors(ni,:));
    end
    set(gca,'XScale','log'); grid on; xlabel('Event probability, alpha');
    ylabel(labels{f}); legend({'N=10: available policy envelope','N=250: available policy envelope'},'Location','best');
end
save_figure(fig,cfg,'fig15_event_probability');
