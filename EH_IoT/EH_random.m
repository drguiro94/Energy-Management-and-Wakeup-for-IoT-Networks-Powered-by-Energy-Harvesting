function energy = EH_random(N,prob,quantity,model)
%EH_RANDOM Independent fixed-quantum Bernoulli EH, Eqs. (5) and (7).
% Inputs: N devices, arrival probability (not rate), quantum, optional model.
% The archive's rand-scaled arrival amount is retained only as 'uniform'.
if nargin<4, model='bernoulli_fixed'; end
assert(prob>=0 && prob<=1, 'EH probability must lie in [0,1].');
energy = quantity*double(rand(N,1)<prob);
if strcmp(model,'uniform'), energy=energy.*rand(N,1); end
end
