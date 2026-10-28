function [net,optimizer] = dt_adam_update(net,g,optimizer,rate,clip)
%DT_ADAM_UPDATE Adam with bias correction and global gradient-norm clipping.
names=fieldnames(net.parameters);
if isempty(optimizer)
    optimizer.iteration=0; optimizer.m=struct(); optimizer.v=struct();
    for j=1:numel(names)
        name=names{j}; optimizer.m.(name)=zeros(size(g.(name)));
        optimizer.v.(name)=zeros(size(g.(name)));
    end
end
norm_squared=0;
for j=1:numel(names), a=g.(names{j}); norm_squared=norm_squared+sum(a(:).^2); end
factor=min(1,clip/max(sqrt(norm_squared),1e-30));
optimizer.iteration=optimizer.iteration+1; t=optimizer.iteration;
for j=1:numel(names)
    name=names{j}; a=factor*g.(name);
    optimizer.m.(name)=0.9*optimizer.m.(name)+0.1*a;
    optimizer.v.(name)=0.999*optimizer.v.(name)+0.001*a.^2;
    mhat=optimizer.m.(name)/(1-0.9^t); vhat=optimizer.v.(name)/(1-0.999^t);
    net.parameters.(name)=net.parameters.(name)-rate*mhat./(sqrt(vhat)+1e-8);
end
end
