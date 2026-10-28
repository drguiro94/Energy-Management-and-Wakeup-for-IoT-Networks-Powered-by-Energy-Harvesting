function [logits,cache] = dt_forward(net,X,valid)
%DT_FORWARD Masked multi-head attention, residuals, layer norms, and FFNs.
% X is [context x input_size]; valid marks real (not left-padding) tokens.
% Keys at future positions and padding positions cannot affect a prediction.
p=net.parameters; L=size(X,1); d=net.d_model;
assert(size(X,2)==net.input_size && L<=net.context,'Invalid DT input size.');
valid=logical(valid(:)); assert(numel(valid)==L,'Invalid padding mask.');
position=zeros(L,d);
for j=1:d
    frequency=10000^(2*floor((j-1)/2)/d);
    if mod(j,2)==1, position(:,j)=sin((0:L-1)'/frequency);
    else, position(:,j)=cos((0:L-1)'/frequency); end
end
H=bsxfun(@plus,X*p.Win,p.bin)+position;
cache.X=X; cache.layers=cell(net.blocks,1);
allowed=tril(true(L)) & bsxfun(@and,valid,valid');
for b=1:net.blocks
    pre=sprintf('b%d_',b); c=struct(); c.H=H;
    [U,c.ln1]=normalize(H,p.([pre 'g1']),p.([pre 'z1']));
    c.U=U; Q=U*p.([pre 'Wq']); K=U*p.([pre 'Wk']); V=U*p.([pre 'Wv']);
    c.Q=Q; c.K=K; c.V=V; c.attention=cell(net.heads,1);
    C=zeros(L,d); width=d/net.heads;
    for head=1:net.heads
        cols=(head-1)*width+(1:width);
        scores=Q(:,cols)*K(:,cols)'/sqrt(width);
        scores(~allowed)=-1e9;
        A=exp(bsxfun(@minus,scores,max(scores,[],2))).*allowed;
        A=bsxfun(@rdivide,A,max(sum(A,2),1e-30));
        C(:,cols)=A*V(:,cols); c.attention{head}=A;
    end
    c.C=C; Y=H+C*p.([pre 'Wo']); c.Y=Y;
    [U2,c.ln2]=normalize(Y,p.([pre 'g2']),p.([pre 'z2'])); c.U2=U2;
    c.pre_relu=bsxfun(@plus,U2*p.([pre 'W1']),p.([pre 'b1']));
    c.relu=max(0,c.pre_relu);
    H=Y+bsxfun(@plus,c.relu*p.([pre 'W2']),p.([pre 'b2']));
    cache.layers{b}=c;
end
cache.H=H;
logits=bsxfun(@plus,H*p.Wout,p.bout);
end

function [Y,c]=normalize(X,gamma,beta)
c.centered=bsxfun(@minus,X,mean(X,2));
c.inverse_std=1./sqrt(mean(c.centered.^2,2)+1e-5);
c.normalized=bsxfun(@times,c.centered,c.inverse_std);
c.gamma=gamma;
Y=bsxfun(@plus,bsxfun(@times,c.normalized,gamma),beta);
end
