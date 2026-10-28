function plot_joint_profile_comparison(paper,archive)
%PLOT_JOINT_PROFILE_COMPARISON Keep physical profiles visibly separate.
% Both panels use the SAME actual-event information and missed-event metrics.
fig=figure('Visible','off','Position',[100 100 1400 900]);
assert(isequal(paper.methods,archive.methods),'Use matching policy sets for the profile comparison.');
runs={paper,archive}; titles={'20 x 20 m; Bernoulli EH, E_B=1','10 x 10 m; uniform EH (ZIP profile)'};
colors=lines(numel(paper.methods)); marks={'o','s','^','d','v','>'};
short=paper.methods;
for m=1:numel(short)
    if any(strcmp(short{m},{'rl','dt'})), short{m}=upper(short{m}); end
end
for column=1:2
    R=runs{column};
    for row=1:2
        ax=subplot(2,2,(row-1)*2+column); hold on;
        if row==1, field='info_per_event'; scale=1; else, field='misdetection'; scale=100; end
        for m=1:numel(R.methods)
            y=scale*R.mean.(field)(m,:); e=scale*R.ci95.(field)(m,:); e(isnan(e))=0;
            h=errorbar(R.N,y,e);
            set(h,'Color',colors(m,:),'Marker',marks{mod(m-1,numel(marks))+1},'LineWidth',1.5);
        end
        grid on; box on; xlabel('Number of IoTDs, N');
        if row==1
            ylabel('Information per actual event'); ylim([0 .85]); title(titles{column});
            legend(short,'Location','northwest');
        else
            ylabel('Missed events (%)'); ylim([0 100]);
        end
        set(ax,'FontSize',11);
    end
end
c=paper.cfg; c.output_dir=fullfile(fileparts(mfilename('fullpath')),'output_joint_audit');
c.figure_formats={'png'};
save_figure(fig,c,'information_detection_comparison');
end
