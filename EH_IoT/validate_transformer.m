function report = validate_transformer()
%VALIDATE_TRANSFORMER Finite-difference gradients, causality, and real learning.
addpath(fileparts(mfilename('fullpath'))); rng(81,'twister');
o.d_model=8; o.heads=2; o.blocks=2; o.ff_size=12; o.context=5;
net=dt_initialize(6,3,o); X=randn(5,6); Y=double(rand(5,3)>0.4);
valid=[false;true;true;true;true]; mask=ones(5,3); mask(3,2)=0;
[loss,g]=dt_loss_gradient(net,X,Y,valid,mask);
names=fieldnames(g); worst=0; step=1e-5; tested=0;
for j=1:numel(names)
    name=names{j}; indices=unique([1 numel(g.(name)) ceil(numel(g.(name))/2)]);
    for index=indices
        plus=net; minus=net;
        plus.parameters.(name)(index)=plus.parameters.(name)(index)+step;
        minus.parameters.(name)(index)=minus.parameters.(name)(index)-step;
        a=dt_loss_gradient(plus,X,Y,valid,mask);
        b=dt_loss_gradient(minus,X,Y,valid,mask);
        numerical=(a-b)/(2*step); analytical=g.(name)(index);
        error=abs(numerical-analytical)/max(1,abs(numerical)+abs(analytical));
        worst=max(worst,error); tested=tested+1;
    end
end
assert(worst<2e-5,'Transformer backpropagation failed numerical gradient checks.');
before=dt_forward(net,X,true(5,1)); altered=X; altered(5,:)=1000*randn(1,6);
after=dt_forward(net,altered,true(5,1));
assert(max(max(abs(before(1:4,:)-after(1:4,:))))<1e-10,'Future tokens leak into past actions.');

% Overfit a tiny objective: successful loss reduction needs actual updates.
original=net; optimizer=[];
for it=1:100
    [current,gradient]=dt_loss_gradient(net,X,Y,valid,mask);
    [net,optimizer]=dt_adam_update(net,gradient,optimizer,0.01,1);
end
last=dt_loss_gradient(net,X,Y,valid,mask);
assert(last<0.2*loss,'Transformer did not learn its training example.');
assert(norm(net.parameters.b1_Wq-original.parameters.b1_Wq,'fro')>1e-5,...
    'Attention projections were not trained.');
report.gradient_checks=tested; report.maximum_gradient_error=worst;
report.initial_loss=loss; report.final_loss=last;
fprintf('DT: %d gradient checks passed (max error %.3g); loss %.4f -> %.4f.\n',tested,worst,loss,last);
end
