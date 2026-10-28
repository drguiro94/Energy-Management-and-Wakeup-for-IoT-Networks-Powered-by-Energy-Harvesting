function [R,levels] = battery_transition_matrix(cfg,costs,weights,step)
%BATTERY_TRANSITION_MATRIX Valid stochastic battery chain, Eqs. (7)-(8).
% costs/weights describe a FIXED externally specified action mixture. A
% coupled adaptive network needs a joint battery/controller state; this
% demonstrator is not substituted for the network's simulated availability.
if nargin<4, step=1/14; end
assert(strcmp(cfg.harvest_model,'bernoulli_fixed'),'This chain assumes fixed-quantum Bernoulli EH.');
assert(step>0 && all(costs>=0) && all(weights>=0) && abs(sum(weights)-1)<1e-12,'Invalid chain inputs.');
units=[cfg.E_max cfg.E_B costs(:)']/step;
assert(all(abs(units-round(units))<1e-8),'Capacity, quantum, and costs must be multiples of step.');
L=round(cfg.E_max/step); h=round(cfg.E_B/step);
levels=(0:L)'*step; rows=(1:L+1)'; indices=(0:L)';
R=sparse(L+1,L+1); p=-expm1(-cfg.lambda*cfg.TTI);
for a=1:numel(costs)
    after=max(0,indices-round(costs(a)/step));
    noEH=after+1; withEH=min(L,after+h)+1;
    R=R+sparse(rows,noEH,(1-p)*weights(a)*ones(L+1,1),L+1,L+1)...
       +sparse(rows,withEH,p*weights(a)*ones(L+1,1),L+1,L+1);
end
assert(max(abs(full(sum(R,2))-1))<1e-12,'Battery matrix is not row stochastic.');
end
