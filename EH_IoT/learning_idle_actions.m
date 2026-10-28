function planned = learning_idle_actions(scores,estimate,k,control,epsilon)
%LEARNING_IDLE_ACTIONS Learned ranking within a documented coverage constraint.
% Independent binary decisions with shared parameters can all be identical.
% A rotating tie break and one member per nonempty eligible spatial group
% prevent that failure without forcing any metric or method ordering.
N=numel(scores); planned=false(N,1); eligible=true(N,1);
if control.energy_guard, eligible=estimate(:)>=control.minimum_energy; end
if strcmp(control.mode,'independent')
    planned=scores(:)>0;
    if epsilon>0
        explore=rand(N,1)<epsilon; planned(explore)=rand(sum(explore),1)>0.5;
    end
    planned=planned & eligible;
    return;
end
if strcmp(control.mode,'coverage_rank')
    % Greedy maximum coverage subject to the estimated-energy awake budget.
    % Learned Q advantages / DT logits and available energy break coverage
    % tradeoffs. Coverage is computed before the event from known geometry.
    % After full coverage, remaining slots can still improve information.
    available=find(eligible);
    if isempty(available), return; end
    z=scores(:); centre=mean(z(available)); spread=std(z(available));
    z=(z-centre)/max(1e-6,spread);
    preference=0.5+0.5*z./(1+abs(z));
    energy=max(0,min(1,estimate(:)/control.maximum_energy));
    covered=false(1,size(control.coverage,2));
    for slot=1:min(control.awake_budget,numel(available))
        candidates=find(eligible & ~planned);
        gain=sum(control.coverage(candidates,~covered),2);
        gain=gain/max(1,max(gain));
        priority=gain+control.learned_weight*preference(candidates)+...
            control.energy_weight*energy(candidates);
        % Deterministic rotating tie break, with explicit training exploration.
        priority=priority+1e-9*mod(candidates-k,N)/N;
        if epsilon>0 && rand<epsilon
            j=candidates(randi(numel(candidates)));
        else
            [~,best]=max(priority); j=candidates(best);
        end
        planned(j)=true; covered=covered | logical(control.coverage(j,:));
    end
    return;
end
for group=unique(control.groups(:))'
    members=find(control.groups==group & eligible);
    if isempty(members), continue; end
    if epsilon>0 && rand<epsilon
        j=members(randi(numel(members)));
    else
        rotate=mod(k-1+control.phase(members),control.cycle(members))==0;
        priority=scores(members)+1e-9*double(rotate);
        [~,best]=max(priority); j=members(best);
    end
    planned(j)=true;
end
end
