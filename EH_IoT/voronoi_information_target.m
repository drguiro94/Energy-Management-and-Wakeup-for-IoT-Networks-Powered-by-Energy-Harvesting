function [target,d_star,cells] = voronoi_information_target(dev,cfg)
%VORONOI_INFORMATION_TARGET Bounded Voronoi cells and Eqs. (21)-(22).
% Unbounded exterior cells would have infinite vertices. Clip every cell to
% the actual monitored rectangle before computing the covering distance.
% Half-plane clipping needs no Statistics/Mapping/Optimization toolbox.
N=size(dev,1); cells=cell(N,1); d_star=0;
for j=1:N
    polygon=[0 0; cfg.A 0; cfg.A cfg.B; 0 cfg.B];
    for h=1:N
        if h==j, continue; end
        a=2*(dev(h,:)-dev(j,:)); b=sum(dev(h,:).^2)-sum(dev(j,:).^2);
        if norm(a)<1e-12, continue; end
        polygon=clip_halfplane(polygon,a,b);
        if isempty(polygon), break; end
    end
    cells{j}=polygon;
    if ~isempty(polygon)
        d_star=max(d_star,max(sqrt(sum(bsxfun(@minus,polygon,dev(j,:)).^2,2))));
    end
end
target=cfg.Psi*exp(-cfg.eta*d_star);
end

function out=clip_halfplane(poly,a,b)
out=zeros(0,2); n=size(poly,1);
for i=1:n
    u=poly(i,:); v=poly(mod(i,n)+1,:);
    iu=dot(a,u)<=b+1e-10; iv=dot(a,v)<=b+1e-10;
    if iu, out(end+1,:)=u; end %#ok<AGROW>
    if iu~=iv
        den=dot(a,v-u);
        if abs(den)>1e-14, out(end+1,:)=u+(b-dot(a,u))/den*(v-u); end %#ok<AGROW>
    end
end
end
