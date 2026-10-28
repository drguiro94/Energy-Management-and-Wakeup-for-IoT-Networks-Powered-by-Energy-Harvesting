function plot_system_model(R)
%PLOT_SYSTEM_MODEL Inspect one real deployment, bounded cells, and battery log.
if ~R.cfg.make_plots || ~isfield(R.example,'trace'), return; end
c=R.cfg; e=R.example; dev=e.trace.dev;
fig=figure('Visible',c.figure_visible,'Position',[100 100 1000 470]);
subplot(1,2,1); hold on;
for j=1:numel(e.cells)
    v=e.cells{j}; if isempty(v), continue; end
    v=[v;v(1,:)]; plot(v(:,1),v(:,2),'-','Color',[0.7 0.7 0.7]);
end
scatter(dev(:,1),dev(:,2),25,e.policy.cluster_idx,'filled');
plot(e.policy.centroids(:,1),e.policy.centroids(:,2),'kx','MarkerSize',10,'LineWidth',2);
axis equal; axis([0 c.A 0 c.B]); xlabel('x (m)'); ylabel('y (m)');
title(sprintf('Bounded cells; d_* = %.2f m',e.d_star)); grid on;
subplot(1,2,2); plot(e.trace.time,e.trace.battery','LineWidth',1);
hold on; plot(e.trace.time,c.Tx_E*ones(size(e.trace.time)),'k--','LineWidth',1.4);
xlabel('Time (normalized TTIs)'); ylabel('Battery (energy units)'); ylim([0 c.E_max]);
title('Actual battery trajectories; dashed line = E_{Tx}'); grid on;
save_figure(fig,c,'system_model');
fig=figure('Visible',c.figure_visible,'Position',[100 100 920 650]);
subplot(3,1,1); plot(e.trace.time,e.trace.mean_battery,'LineWidth',1.2);
ylabel('Mean battery'); grid on;
subplot(3,1,2); stairs(e.trace.time,e.trace.info,'LineWidth',1);
ylabel('Information'); grid on;
subplot(3,1,3); stairs(e.trace.time,e.trace.state(1,:),'LineWidth',1);
set(gca,'YTick',1:4,'YTickLabel',{'idle','sense','Tx','sleep'}); ylim([0.7 4.3]);
xlabel('Time (normalized TTIs)'); ylabel('Device 1 state'); grid on;
save_figure(fig,c,'system_trace');
end
