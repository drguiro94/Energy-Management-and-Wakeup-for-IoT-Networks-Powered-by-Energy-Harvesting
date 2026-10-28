function plot_information_focus(paper,archive)
%PLOT_INFORMATION_FOCUS Compare the Fig. 7 metric under labeled model settings.
% Points are fresh per-actual-event measurements. No curve-fitting, scaling,
% monotonic sorting, or confidence intervals from a single deployment.
cfg=paper.cfg;
cfg.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_information_focus');
fig=figure('Visible',cfg.figure_visible,'Position',[80 100 1400 720]);
sets={paper,archive}; captions={'20 x 20 m; Bernoulli EH, E_B=1','10 x 10 m; archive-compatible uniform EH'};
colors=[0.3 0.3 0.3;0.85 0.35 0.1;0 0.35 0.75;0.1 0.6 0.25;0.55 0.2 0.65];
markers={'o','s','^','d','v'};
for panel=1:2
    R=sets{panel}; subplot(1,2,panel); hold on;
    for method=1:numel(R.methods)
        plot(R.N,R.mean.info_per_event(method,:),...
            'Color',colors(method,:),'Marker',markers{method},'LineWidth',1.7,'MarkerSize',6);
    end
    radius=sqrt(R.cfg.A*R.cfg.B./(pi*R.N)); z=R.cfg.eta*radius;
    bound=2*(-expm1(-z)-z.*exp(-z))./(z.^2);
    plot(R.N,bound,'k--','LineWidth',1.2);
    plot(250,0.72,'kp','MarkerSize',10,'LineWidth',1.5);
    xlabel('Number of IoTDs, N (one deployment per N)'); ylabel('Mean information per actual event');
    title([captions{panel} ' (10000 TTIs)'],'Interpreter','none');
    ylim([0 0.85]); xlim([0 265]); grid on; box on;
    labels=R.labels; labels{end+1}='Any-placement information bound';
    labels{end+1}='Reported RL reference near 0.72';
    ax=gca; key=legend(labels,'Location','southoutside','Interpreter','none');
    set(ax,'Units','normalized','Position',[0.07+(panel-1)*0.49 0.39 0.40 0.52]);
    set(key,'Units','normalized','Position',[0.085+(panel-1)*0.49 0.02 0.38 0.27]);
    set(gca,'FontSize',10);
end
save_figure(fig,cfg,'information_per_event_focus');
end
