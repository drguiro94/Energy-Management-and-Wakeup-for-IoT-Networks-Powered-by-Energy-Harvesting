function plot_energy_budget(R)
%PLOT_ENERGY_BUDGET Figs. 13-14 type analytical fixed-consumption budgets.
% These are NOT re-simulations under changed EH probability. They overlay
% E[H]=p_eh*E_B with consumption measured at the baseline setting.
c=R.cfg; p=linspace(0,1,201); colors=lines(3); quanta=[1 5 10];
fig=figure('Visible',c.figure_visible,'Position',[100 100 880 550]); hold on;
labels={};
for j=1:3
    plot(p,p*quanta(j),'LineWidth',1.7,'Color',colors(j,:));
    labels{end+1}=sprintf('E_B = %g',quanta(j)); 
end
for j=[1 numel(R.N)]
    values=R.mean.energy_actual(:,j); lo=min(values); hi=max(values);
    plot(p,lo*ones(size(p)),'--','LineWidth',1);
    plot(p,hi*ones(size(p)),':','LineWidth',1);
    labels{end+1}=sprintf('N=%d: min measured use',R.N(j)); 
    labels{end+1}=sprintf('N=%d: max measured use',R.N(j)); 
end
xlabel('EH arrival probability, p_{eh}'); ylabel('Energy / IoTD / TTI');
title('Analytical input budget with fixed baseline consumption'); grid on;
legend(labels,'Location','eastoutside'); save_figure(fig,c,'fig13_harvest_budget');
[~,j]=min(abs(R.N-100)); lo=min(R.mean.energy_actual(:,j)); hi=max(R.mean.energy_actual(:,j));
fig=figure('Visible',c.figure_visible,'Position',[100 100 880 550]); hold on;
labels={};
for q=1:3
    plot(p,p*quanta(q)-lo,'-','Color',colors(q,:),'LineWidth',1.5);
    plot(p,p*quanta(q)-hi,'--','Color',colors(q,:),'LineWidth',1.5);
    labels{end+1}=sprintf('E_B=%g, minimum use',quanta(q)); 
    labels{end+1}=sprintf('E_B=%g, maximum use',quanta(q)); 
end
plot(p,zeros(size(p)),'k:','HandleVisibility','off');
xlabel('EH arrival probability, p_{eh}'); ylabel('Input minus fixed use / IoTD / TTI');
title(sprintf('Analytical fixed-consumption budget, N=%d',R.N(j))); grid on;
legend(labels,'Location','eastoutside'); save_figure(fig,c,'fig14_net_budget');
end
