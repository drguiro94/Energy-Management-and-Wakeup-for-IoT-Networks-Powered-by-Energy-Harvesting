function plot_results(R)
%PLOT_RESULTS Same metric families as journal Figs. 7-12, from fresh samples.
if ~R.cfg.make_plots, return; end
spec={...
    'info_per_expected_event',1,'Information per expected event','fig07_information';...
    'energy_actual',1,'Actual energy / IoTD / TTI','fig08_energy_actual';...
    'misdetection',100,'Misdetections (%)','fig09_misdetection';...
    'low_energy',100,'IoTDs with B < E_{Tx} (%)','fig10_low_energy';...
    'mean_battery',1,'Mean battery (energy units)','fig11_mean_battery';...
    'wrong_percent',1,'Unsuccessful activations (%)','fig12a_wrong_activations';...
    'wasted_energy_per_device_event',1,'Wasted energy / IoTD / event','fig12b_wasted_energy';...
    'energy_requested',1,'Requested energy / IoTD / TTI','energy_requested';...
    'elapsed_seconds',1,'Simulation runtime / deployment (s)','runtime';...
    'net_stored',1,'Stored harvest - actual use / IoTD / TTI','net_stored_energy'};
colors=lines(numel(R.methods)); marks={'o','s','^','d','v','>'};
for f=1:size(spec,1)
    fig=figure('Visible',R.cfg.figure_visible,'Position',[100 100 900 560]); hold on;
    for mi=1:numel(R.methods)
        y=spec{f,2}*R.mean.(spec{f,1})(mi,:);
        e=spec{f,2}*R.ci95.(spec{f,1})(mi,:);
        if all(isnan(e)), e=zeros(size(e)); end
        h=errorbar(R.N,y,e);
        set(h,'Color',colors(mi,:),'Marker',marks{mod(mi-1,numel(marks))+1},'LineWidth',1.4);
    end
    xlabel('Number of IoTDs, N'); ylabel(spec{f,3}); grid on; box on;
    legend(R.labels,'Location','eastoutside','Interpreter','none');
    set(gca,'FontSize',11);
    counts=R.count.(spec{f,1});
    if any(counts(:)>=2)
        title('Fresh simulations; 95% intervals where estimable');
    else
        title('Fresh simulations; one deployment per count (no interval)');
    end
    save_figure(fig,R.cfg,spec{f,4});
end
plot_energy_budget(R);
end
