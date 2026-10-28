function [order,score] = wake_close_device(pair_distance,info,excluded,cfg,lookup)
%WAKE_CLOSE_DEVICE Rank sleeping candidates by report-conditioned score.
% Corrects the archive's index-order selection and its loop that accidentally
% modified only the strongest reporter instead of its neighboring devices.
N=numel(info); score=zeros(N,1); reporters=find(info>0);
if ~isempty(reporters)
    if cfg.eta==0
        r=zeros(numel(reporters),1); % Strength has no ranging information when eta=0.
        % Uniform event bearing at the sensor is then not identifiable;
        % a distance-only proxy is used and explicitly documented.
    else
        r=max(0,min(cfg.active_distance,-log(min(1,info(reporters)/cfg.Psi))/cfg.eta));
    end
    % correlation_lookup creates a regular grid. Vectorized bilinear
    % interpolation is equivalent to interp2(...,'linear'), but avoids a
    % separate interpolation setup for every received reporter.
    x=pair_distance(:,reporters); y=repmat(r(:)',N,1);
    gx=(x-lookup.gamma(1))/(lookup.gamma(2)-lookup.gamma(1));
    gy=(y-lookup.r(1))/(lookup.r(2)-lookup.r(1));
    ix=min(numel(lookup.gamma)-1,max(1,floor(gx)+1));
    iy=min(numel(lookup.r)-1,max(1,floor(gy)+1));
    tx=gx-(ix-1); ty=gy-(iy-1); rows=numel(lookup.r);
    lower=iy+(ix-1)*rows;
    estimate=(1-ty).*((1-tx).*lookup.value(lower)+tx.*lookup.value(lower+rows))+...
        ty.*((1-tx).*lookup.value(lower+1)+tx.*lookup.value(lower+rows+1));
    score=max(estimate,[],2);
end
score(logical(excluded))=0;
eligible=find(~excluded(:) & score>=exp(-cfg.eta*cfg.active_distance));
[~,rank]=sort(score(eligible),'descend'); order=eligible(rank);
end
