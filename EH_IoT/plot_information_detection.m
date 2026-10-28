function plot_information_detection(R)
%PLOT_INFORMATION_DETECTION Report both requested outcomes, with honest CIs.
if ~R.cfg.make_plots, return; end
spec={'info_per_event',1,'Information per actual event','fig07_information_per_event';...
    'misdetection',100,'Missed events (%)','fig09_misdetection'};
colors=lines(numel(R.methods)); marks={'o','s','^','d','v','>'};
for f=1:size(spec,1)
    fig=figure('Visible',R.cfg.figure_visible,'Position',[100 100 1000 600]); hold on;
    for m=1:numel(R.methods)
        mu=spec{f,2}*R.mean.(spec{f,1})(m,:);
        half=spec{f,2}*R.ci95.(spec{f,1})(m,:);
        % No errorbar is inferable for one deployment; mark the title.
        half(isnan(half))=0;
        h=errorbar(R.N,mu,half);
        set(h,'Color',colors(m,:),'Marker',marks{mod(m-1,numel(marks))+1},'LineWidth',1.5);
    end
    xlabel('Number of IoTDs, N'); ylabel(spec{f,3}); grid on; box on;
    if f==2
        ylim([0 100]); % Physical range; full untruncated half-widths are in CSV.
    elseif strcmp(R.cfg.aggregation,'max')
        ylim([0 R.cfg.Psi]);
    end
    legend(R.labels,'Location','eastoutside','Interpreter','none');
    if all(R.count.info_per_event(:)>=2)
        title('Fresh deployments; 95% intervals across deployment means');
    else
        title('Fresh tests; intervals only where multiple deployments exist');
    end
    save_figure(fig,R.cfg,spec{f,4});
end
fid=fopen(fullfile(R.cfg.output_dir,'information_detection.csv'),'w');
assert(fid>=0,'Cannot create joint metrics CSV.'); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'N,method,information_per_actual_event,information_ci95,miss_fraction,miss_ci95,deployments,event_count,miss_count,information_per_expected_event\n');
for ni=1:numel(R.N)
    for m=1:numel(R.methods)
        fprintf(fid,'%d,%s,%.12g,%.12g,%.12g,%.12g,%d,%.12g,%.12g,%.12g\n',...
            R.N(ni),R.methods{m},R.mean.info_per_event(m,ni),R.ci95.info_per_event(m,ni),...
            R.mean.misdetection(m,ni),R.ci95.misdetection(m,ni),R.count.info_per_event(m,ni),...
            sum(R.raw.event_count(:,m,ni)),sum(R.raw.miss_count(:,m,ni)),R.mean.info_per_expected_event(m,ni));
    end
end
end
