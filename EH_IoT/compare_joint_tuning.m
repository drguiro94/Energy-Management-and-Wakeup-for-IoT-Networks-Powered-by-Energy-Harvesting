function rows = compare_joint_tuning()
%COMPARE_JOINT_TUNING Paired first-deployment comparison to earlier results.
% New three-deployment means are reported separately; they are never compared
% with an old single-deployment number as though both were a paired average.
root=fileparts(mfilename('fullpath')); models={'paper','archive_compatibility'};
rows=[];
for profile=1:numel(models)
    before=load(fullfile(root,['output_tuned_test_' models{profile}],'results.mat'),'Results');
    after=load(fullfile(root,['output_joint_test_' models{profile}],'results.mat'),'Results');
    B=before.Results; A=after.Results;
    assert(isequal(B.N,A.N) && isequal(B.methods,A.methods),'Comparison cases differ.');
    for n=1:numel(A.N)
        % Baselines use the identical seeds and physical parameters. Their
        % equality is an independent check of the paired scenario identity.
        for method={'random','cluster','genie'}
            k=find(strcmp(A.methods,method{1}));
            assert(abs(A.raw.info_per_event(1,k,n)-B.raw.info_per_event(1,k,n))<1e-10,...
                'Paired baseline information differs; check scenario/geometry seeds.');
            assert(A.raw.miss_count(1,k,n)==B.raw.miss_count(1,k,n),'Paired missed-event counts differ.');
        end
        for method={'rl','dt'}
            k=find(strcmp(A.methods,method{1}));
            assert(isequal(A.policy{k,n}.deployment,B.policy{k,n}.deployment),'Paired deployments differ.');
            old_I=B.raw.info_per_event(1,k,n); new_I=A.raw.info_per_event(1,k,n);
            old_miss=B.raw.misdetection(1,k,n); new_miss=A.raw.misdetection(1,k,n);
            rows(end+1,:)=[profile A.N(n) 1+strcmp(method{1},'dt')...
                old_I new_I old_miss new_miss new_I-old_I new_miss-old_miss]; 
        end
    end
end
folder=fullfile(root,'output_joint_audit'); if ~exist(folder,'dir'), mkdir(folder); end
save(fullfile(folder,'paired_comparison.mat'),'rows','models','-v7');
fid=fopen(fullfile(folder,'paired_before_after.csv'),'w'); assert(fid>=0); cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'model_1_paper_2_archive,N,method_1_RL_2_DT,old_information,new_information,old_miss,new_miss,information_change,miss_change\n');
for j=1:size(rows,1)
    fprintf(fid,'%.12g',rows(j,1)); fprintf(fid,',%.12g',rows(j,2:end)); fprintf(fid,'\n');
end
end
