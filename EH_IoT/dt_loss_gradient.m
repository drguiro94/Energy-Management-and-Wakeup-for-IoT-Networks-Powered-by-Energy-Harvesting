function [loss,g] = dt_loss_gradient(net,X,Y,valid,action_mask)
%DT_LOSS_GRADIENT Exact backpropagation through ALL transformer parameters.
% The stable binary cross-entropy models N binary control actions per token.
% action_mask removes unavailable wake decisions and padded training tokens.
if nargout>1, [z,c]=dt_forward(net,X,valid); else, z=dt_forward(net,X,valid); end
weights=bsxfun(@times,double(action_mask),double(valid(:)));
den=max(1,sum(weights(:)));
loss_terms=max(z,0)-z.*Y+log1p(exp(-abs(z)));
loss=sum(sum(weights.*loss_terms))/den;
if nargout<2, return; end % Held-out loss needs no backpropagation.
p=net.parameters;
prob=stable_sigmoid(z);
dz=(prob-Y).*weights/den;
names=fieldnames(p); g=struct();
for j=1:numel(names), g.(names{j})=zeros(size(p.(names{j}))); end
g.Wout=c.H'*dz; g.bout=sum(dz,1); dH=dz*p.Wout';
width=net.d_model/net.heads;
for b=net.blocks:-1:1
    pre=sprintf('b%d_',b); t=c.layers{b};
    g.([pre 'W2'])=t.relu'*dH; g.([pre 'b2'])=sum(dH,1);
    dpre=(dH*p.([pre 'W2'])').*(t.pre_relu>0);
    g.([pre 'W1'])=t.U2'*dpre; g.([pre 'b1'])=sum(dpre,1);
    [dY,g.([pre 'g2']),g.([pre 'z2'])]=normalize_backward(dpre*p.([pre 'W1'])',t.ln2);
    dY=dY+dH; % Residual around the feed-forward network
    g.([pre 'Wo'])=t.C'*dY; dC=dY*p.([pre 'Wo'])';
    dQ=zeros(size(t.Q)); dK=dQ; dV=dQ;
    for head=1:net.heads
        cols=(head-1)*width+(1:width); A=t.attention{head};
        dA=dC(:,cols)*t.V(:,cols)';
        dV(:,cols)=A'*dC(:,cols);
        ds=A.*bsxfun(@minus,dA,sum(dA.*A,2));
        dQ(:,cols)=ds*t.K(:,cols)/sqrt(width);
        dK(:,cols)=ds'*t.Q(:,cols)/sqrt(width);
    end
    g.([pre 'Wq'])=t.U'*dQ; g.([pre 'Wk'])=t.U'*dK; g.([pre 'Wv'])=t.U'*dV;
    dU=dQ*p.([pre 'Wq'])'+dK*p.([pre 'Wk'])'+dV*p.([pre 'Wv'])';
    [dX,g.([pre 'g1']),g.([pre 'z1'])]=normalize_backward(dU,t.ln1);
    dH=dY+dX; % Residual around causal attention
end
g.Win=c.X'*dH; g.bin=sum(dH,1);
end

function p=stable_sigmoid(z)
p=zeros(size(z)); positive=z>=0;
p(positive)=1./(1+exp(-z(positive)));
a=exp(z(~positive)); p(~positive)=a./(1+a);
end

function [dx,dgamma,dbeta]=normalize_backward(dy,c)
dgamma=sum(dy.*c.normalized,1); dbeta=sum(dy,1);
v=bsxfun(@times,dy,c.gamma); d=size(v,2);
dx=bsxfun(@times,bsxfun(@minus,d*v,sum(v,2))-...
    bsxfun(@times,c.normalized,sum(v.*c.normalized,2)),c.inverse_std/d);
end
