function plot_information_curve(R)
%PLOT_INFORMATION_CURVE Focused Fig. 7-style output, with both normalizations.
% Actual-event information is plotted; Eq. (18)'s alpha*K value is exported
% beside it. Intervals are across independent deployments, never TTIs.
if ~R.cfg.make_plots, return; end
fig=figure('Visible',R.cfg.figure_visible,'Position',[100 100 1000 600]); hold on;
colors=lines(numel(R.methods)); marks={'o','s','^','d','v','>'};
for m=1:numel(R.methods)
    mu=R.mean.info_per_event(m,:); half=R.ci95.info_per_event(m,:);
    if all(isnan(half)), half=zeros(size(half)); end
    h=errorbar(R.N,mu,half);
    set(h,'Color',colors(m,:),'Marker',marks{m},'LineWidth',1.6);
end
xlabel('Number of IoTDs, N'); ylabel('Mean information per actual event');
grid on; box on; legend(R.labels,'Location','eastoutside','Interpreter','none');
if any(R.count.info_per_event(:)>=2)
    title('Information per event; 95% intervals across deployments');
else
    title('Information per event; one deployment per N (no interval)');
end
save_figure(fig,R.cfg,'fig07_information_per_event');
fid=fopen(fullfile(R.cfg.output_dir,'information_per_event.csv'),'w');
assert(fid>=0,'Cannot create focused information CSV.'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'N,method,information_per_actual_event,ci95_half,deployments,information_per_expected_event\n');
for ni=1:numel(R.N)
    for m=1:numel(R.methods)
        fprintf(fid,'%d,%s,%.12g,%.12g,%d,%.12g\n',R.N(ni),R.methods{m},...
            R.mean.info_per_event(m,ni),R.ci95.info_per_event(m,ni),...
            R.count.info_per_event(m,ni),R.mean.info_per_expected_event(m,ni));
    end
end
end
