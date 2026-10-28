function [idx,centroids,clusters,cycle,phase] = kmeans_cluster(dev,cfg,M)
%KMEANS_CLUSTER Toolbox-free version of the archive's spatial clustering.
% The paper calls its method KNN-based; the supplied implementation uses
% k-means. We retain that actual implementation family and label it honestly.
% The fixed ten-cluster setting is replaced by Algorithm 1's area/(pi*dmax^2).
N=size(dev,1);
if nargin<3, M=ceil(cfg.A*cfg.B/(pi*cfg.active_distance^2)); end
M=min(N,max(1,round(M)));
best_loss=Inf; best_idx=[]; best_cent=[];
for rep=1:cfg.cluster_replicates
    centroids=zeros(M,2); centroids(1,:)=dev(randi(N),:);
    nearest=Inf(N,1);
    for m=2:M
        nearest=min(nearest,sum(bsxfun(@minus,dev,centroids(m-1,:)).^2,2));
        [~,farthest]=max(nearest); centroids(m,:)=dev(farthest,:);
    end
    old=zeros(N,1);
    for it=1:cfg.cluster_iterations
        D=zeros(N,M);
        for m=1:M, D(:,m)=sum(bsxfun(@minus,dev,centroids(m,:)).^2,2); end
        [dist,idx]=min(D,[],2);
        % Empty-cluster repair keeps all M sensing groups usable.
        for m=1:M
            if ~any(idx==m)
                counts=accumarray(idx,1,[M 1]);
                eligible=counts(idx)>1;
                score=dist; score(~eligible)=-Inf;
                [~,j]=max(score); idx(j)=m; dist(j)=0;
            end
        end
        for m=1:M, centroids(m,:)=mean(dev(idx==m,:),1); end
        if isequal(old,idx), break; end
        old=idx;
    end
    loss=sum(sum((dev-centroids(idx,:)).^2));
    if loss<best_loss, best_loss=loss; best_idx=idx; best_cent=centroids; end
end
idx=best_idx; centroids=best_cent; clusters=cell(M,1);
cycle=ones(N,1); phase=zeros(N,1);
for m=1:M
    members=find(idx==m); clusters{m}=members;
    cycle(members)=numel(members); phase(members)=(0:numel(members)-1)';
end
end
