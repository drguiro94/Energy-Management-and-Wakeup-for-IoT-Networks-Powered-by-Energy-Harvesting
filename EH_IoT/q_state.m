function index = q_state(battery_estimate,score,info,active_neighbors,delta,N,cfg)
%Q_STATE Shared finite LOCAL state for the optional Q-learning reference.
% Features use estimates/history, not true event locations or future EH.
% 5 battery x 4 score x 4 received-info x 3 neighbors x 2 delta x 3 density.
b=bin(battery_estimate(:)/cfg.E_max,[0.1 0.25 0.5 0.75]);
p=bin(score(:),[0.02 0.1 0.4]);
i=bin(info/cfg.Psi,[0.02 0.1 0.4]);
a=bin(active_neighbors(:),[1 3]);
d=bin(N/(cfg.A*cfg.B),[0.1 0.4]);
index=b+5*(p-1)+20*(i-1)+80*(a-1)+240*double(delta(:))+480*(d-1);
end

function b=bin(x,edges)
b=1+sum(bsxfun(@ge,x,edges),2);
end
