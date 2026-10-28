function Results = combine_information_test_cases(model,counts)
%COMBINE_INFORMATION_TEST_CASES Concatenate independent count-specific runs.
% If splitting a run by count, use seed_offset=(count_index-1)*10000 to match
% run_experiments' ordinary deployment/training seeds.
if nargin<2, counts=[10 50 250]; end
cfg=recommended_config(model); cfg.N_values=counts; cfg.MCarlo=1; cfg.total=10000;
root=cfg.output_dir; runs=cell(size(counts));
for j=1:numel(counts)
    path=fullfile(root,sprintf('case_N%d',counts(j)),'results.mat');
    data=load(path,'Results'); runs{j}=data.Results;
    assert(runs{j}.N==counts(j) && all(runs{j}.completed(:)),'Incomplete count-specific test.');
end
Results=runs{1}; Results.cfg=cfg; Results.N=counts;
names=fieldnames(Results.raw);
for f=1:numel(names)
    raw=cell(size(counts)); means=raw; half=raw; number=raw;
    for j=1:numel(counts)
        raw{j}=runs{j}.raw.(names{f}); means{j}=runs{j}.mean.(names{f});
        half{j}=runs{j}.ci95.(names{f}); number{j}=runs{j}.count.(names{f});
    end
    Results.raw.(names{f})=cat(3,raw{:}); Results.mean.(names{f})=cat(2,means{:});
    Results.ci95.(names{f})=cat(2,half{:}); Results.count.(names{f})=cat(2,number{:});
end
Results.policy=cell(numel(Results.methods),numel(counts)); Results.completed=true(1,numel(counts));
for j=1:numel(counts), Results.policy(:,j)=runs{j}.policy; end
for m=1:numel(Results.methods)
    a=cell(size(counts));
    for j=1:numel(counts), a{j}=runs{j}.legacy{m}; end
    Results.legacy{m}=cat(2,a{:});
end
Results.example=runs{min(2,numel(runs))}.example;
save(fullfile(root,'results.mat'),'Results','-v7');
write_results_csv(Results);
model_dir=fullfile(root,'models'); if ~exist(model_dir,'dir'), mkdir(model_dir); end
for j=1:numel(counts)
    source=dir(fullfile(root,sprintf('case_N%d',counts(j)),'models','*.mat'));
    for k=1:numel(source)
        copyfile(fullfile(source(k).folder,source(k).name),fullfile(model_dir,source(k).name));
    end
end
end
