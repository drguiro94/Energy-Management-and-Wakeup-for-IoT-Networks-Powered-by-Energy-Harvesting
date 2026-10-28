function q = shared_q_update(q,state,action,target,rate)
%SHARED_Q_UPDATE Simultaneous parameter-sharing updates averaged per table cell.
if isempty(state), return; end
if isscalar(target), target=target*ones(size(state)); end
linear=state(:)+size(q,1)*(action(:)-1);
delta=target(:)-q(linear);
count=accumarray(linear,1,[numel(q) 1]);
change=accumarray(linear,delta,[numel(q) 1]); used=find(count);
q(used)=q(used)+rate*change(used)./count(used);
end
