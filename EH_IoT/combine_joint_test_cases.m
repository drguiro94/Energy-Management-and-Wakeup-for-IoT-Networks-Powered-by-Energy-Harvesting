function Results = combine_joint_test_cases(model,counts,repetitions)
%COMBINE_JOINT_TEST_CASES Join count-specific runs without changing samples.
% Offset cfg.seed by (count_index-1)*10000 before a single-count job to match
% the ordinary multi-count runner exactly, including training seeds.
if nargin<2, counts=[10 50 250]; end
if nargin<3, repetitions=3; end
cfg=recommended_information_detection_config(model);
cfg.N_values=counts; cfg.MCarlo=repetitions; cfg.total=10000;
root=cfg.output_dir; runs=cell(size(counts));
for j=1:numel(counts)
    data=load(fullfile(root,sprintf('case_N%d',counts(j)),'results.mat'),'Results');
    runs{j}=data.Results;
    assert(runs{j}.N==counts(j) && size(runs{j}.completed,1)==repetitions && all(runs{j}.completed(:)),...
        'Incomplete or mismatched count-specific test.');
    assert(isequal(runs{j}.methods,cfg.methods),'Policy order changed between jobs.');
end
Results=runs{1}; Results.cfg=cfg; Results.N=counts; names=fieldnames(Results.raw);
for f=1:numel(names)
    raw=cell(size(counts)); mu=raw; half=raw; number=raw;
    for j=1:numel(counts)
        raw{j}=runs{j}.raw.(names{f}); mu{j}=runs{j}.mean.(names{f});
        half{j}=runs{j}.ci95.(names{f}); number{j}=runs{j}.count.(names{f});
    end
    Results.raw.(names{f})=cat(3,raw{:}); Results.mean.(names{f})=cat(2,mu{:});
    Results.ci95.(names{f})=cat(2,half{:}); Results.count.(names{f})=cat(2,number{:});
end
Results.policy=cell(numel(Results.methods),numel(counts)); Results.completed=true(repetitions,numel(counts));
for j=1:numel(counts), Results.policy(:,j)=runs{j}.policy; end
for m=1:numel(Results.methods)
    matrix=cell(size(counts));
    for j=1:numel(counts), matrix{j}=runs{j}.legacy{m}; end
    Results.legacy{m}=cat(2,matrix{:});
end
Results.example=runs{min(2,numel(runs))}.example;
save(fullfile(root,'results.mat'),'Results','-v7'); write_results_csv(Results);
model_dir=fullfile(root,'models'); if ~exist(model_dir,'dir'), mkdir(model_dir); end
for j=1:numel(counts)
    source=dir(fullfile(root,sprintf('case_N%d',counts(j)),'models','*.mat'));
    for k=1:numel(source)
        copyfile(fullfile(source(k).folder,source(k).name),fullfile(model_dir,source(k).name));
    end
end
end
