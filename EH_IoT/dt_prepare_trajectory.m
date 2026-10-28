function trajectory = dt_prepare_trajectory(log,stage,discount)
%DT_PREPARE_TRAJECTORY Offline return-to-go and shifted behavioral history.
% Future rewards are used ONLY to define the offline conditioning target.
% The current action label and current outcome are not input features.
T=size(log.state,1); N=size(log.action,2);
G=zeros(T,1); running=0;
for t=T:-1:1
    running=log.reward(t)+discount*running;
    G(t)=(1-discount)*running;
end
prior_action=[zeros(1,N);log.action(1:max(0,T-1),:)];
feedback=log.reward;
if isfield(log,'feedback_reward'), feedback=log.feedback_reward; end
prior_reward=[0;feedback(1:max(0,T-1))];
if T==0
    trajectory.X=zeros(0,size(log.state,2)+N+3);
else
    trajectory.X=[log.state prior_action prior_reward G stage*ones(T,1)];
end
trajectory.Y=log.action; trajectory.action_mask=log.eligible;
trajectory.returns=G; trajectory.stage=stage;
end
