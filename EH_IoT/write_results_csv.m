function write_results_csv(R)
%WRITE_RESULTS_CSV Summary means/95% half-widths plus per-deployment samples.
names=fieldnames(R.raw); cfg=R.cfg;
fid=fopen(fullfile(cfg.output_dir,'summary.csv'),'w');
assert(fid>=0,'Cannot create summary.csv.'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'N,method');
for f=1:numel(names), fprintf(fid,',%s_mean,%s_ci95,%s_n',names{f},names{f},names{f}); end
fprintf(fid,'\n');
for ni=1:numel(R.N)
    for mi=1:numel(R.methods)
        fprintf(fid,'%d,%s',R.N(ni),R.methods{mi});
        for f=1:numel(names)
            fprintf(fid,',%.12g,%.12g,%d',R.mean.(names{f})(mi,ni),...
                R.ci95.(names{f})(mi,ni),R.count.(names{f})(mi,ni));
        end
        fprintf(fid,'\n');
    end
end
clear cleanup;
fid=fopen(fullfile(cfg.output_dir,'samples.csv'),'w');
assert(fid>=0,'Cannot create samples.csv.'); cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'N,method,trial');
for f=1:numel(names), fprintf(fid,',%s',names{f}); end
fprintf(fid,'\n');
for ni=1:numel(R.N)
    for mi=1:numel(R.methods)
        for rep=1:cfg.MCarlo
            fprintf(fid,'%d,%s,%d',R.N(ni),R.methods{mi},rep);
            for f=1:numel(names), fprintf(fid,',%.12g',R.raw.(names{f})(rep,mi,ni)); end
            fprintf(fid,'\n');
        end
    end
end
end
