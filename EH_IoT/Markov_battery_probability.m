%% BATTERY MARKOV-CHAIN DEMONSTRATION -- SECTION III-B
% A separate fixed-action-mixture example, not the full adaptive policy chain.
clear; clc;
addpath(fileparts(mfilename('fullpath')));
cfg=paper_config('quick');
costs=[cfg.wake_up_Energy cfg.idle_E cfg.idle_E+cfg.Tx_E];
weights=[0.95 0.045 0.005]; % Explicit illustrative duty/action probabilities
[R,levels]=battery_transition_matrix(cfg,costs,weights,1/14);
b=zeros(numel(levels),1); b(end)=1; % Start at a full battery
converged=false;
for iteration=1:100000
    next=R'*b;
    if norm(next-b,1)<1e-11, b=next; converged=true; break; end
    b=next;
end
residual=norm(R'*b-b,1);
fprintf('Row-sum error: %.3g\n',max(abs(full(sum(R,2))-1)));
fprintf('Stationarity residual: %.3g (converged=%d)\n',residual,converged);
fprintf('Pr(B >= E_Tx): %.8f\n',sum(b(levels>=cfg.Tx_E)));
fprintf('Pr(B >= E_idle): %.8f\n',sum(b(levels>=cfg.idle_E)));
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
save(fullfile(cfg.output_dir,'battery_markov.mat'),'R','levels','b','costs','weights','residual','converged','-v7');
fig=figure('Visible',cfg.figure_visible,'Position',[100 100 760 430]);
plot(levels,b,'LineWidth',1.3); xlabel('Battery (energy units)');
ylabel('Stationary probability'); title('Specified fixed action mixture'); grid on;
save_figure(fig,cfg,'battery_markov');
