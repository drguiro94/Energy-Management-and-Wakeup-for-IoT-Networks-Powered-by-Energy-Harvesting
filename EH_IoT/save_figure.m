function save_figure(fig,cfg,name)
%SAVE_FIGURE Portable exports with consistent sizes; no external MAT data.
if ~exist(cfg.output_dir,'dir'), mkdir(cfg.output_dir); end
set(fig,'Color','w','PaperPositionMode','auto');
drawnow;
for i=1:numel(cfg.figure_formats)
    extension=cfg.figure_formats{i}; path=fullfile(cfg.output_dir,[name '.' extension]);
    switch extension
        case 'png', print(fig,path,'-dpng','-r160');
        case 'eps', print(fig,path,'-depsc');
        case 'pdf', print(fig,path,'-dpdf');
        otherwise, error('Unsupported figure format: %s',extension);
    end
end
close(fig);
end
