function plot_learning(R)
%PLOT_LEARNING RL rewards and train/held-out transformer losses, from logs.
if ~R.cfg.make_plots, return; end
for ni=1:numel(R.N)
    for mi=1:numel(R.methods)
        p=R.policy{mi,ni};
        if strcmp(p.type,'rl')
            h=p.training_history;
            fig=figure('Visible',R.cfg.figure_visible,'Position',[100 100 900 520]);
            subplot(2,1,1); plot(h(:,1),h(:,2:3),'LineWidth',1.4); grid on;
            idle_label='Idle/sleep, Eq. (24)';
            if isfield(R.cfg.rl,'reward_mode') && strcmp(R.cfg.rl.reward_mode,'information_detection')
                idle_label='Idle/sleep, joint task reward';
            end
            ylabel('Training reward'); legend({idle_label,'Extra reports, Eq. (25)'},'Location','eastoutside');
            title(sprintf('Two-stage RL, N=%d (reconstructed)',R.N(ni)));
            subplot(2,1,2); use=isfinite(h(:,6)); plot(h(use,1),h(use,6),'o-','LineWidth',1.4);
            xlabel('Training episode'); ylabel('Held-out objective'); grid on;
            save_figure(fig,R.cfg,sprintf('rl_training_N%d',R.N(ni)));
        elseif strcmp(p.type,'dt')
            fig=figure('Visible',R.cfg.figure_visible,'Position',[100 100 900 800]);
            models={p.dt.idle,p.dt.wake}; stage_names={'Idle/sleep policy','Extra-report policy'};
            for stage=1:2
                subplot(2,1,stage); h=models{stage}.training_history;
                plot(h(:,1),h(:,2),'-','LineWidth',1.1); hold on;
                keep=isfinite(h(:,3)); plot(h(keep,1),h(keep,3),'o-','LineWidth',1.5);
                if stage==2, xlabel('Adam update'); end
                ylabel('Masked binary cross-entropy'); grid on;
                title(sprintf('DT %s, N=%d',stage_names{stage},R.N(ni)));
                legend({'Training minibatch','Held-out episode'},'Location','eastoutside');
            end
            save_figure(fig,R.cfg,sprintf('dt_training_N%d',R.N(ni)));
        end
    end
end
end
