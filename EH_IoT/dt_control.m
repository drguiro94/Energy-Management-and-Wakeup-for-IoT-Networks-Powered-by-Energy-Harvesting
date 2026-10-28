function [action,runtime,scores] = dt_control(model,observation,runtime,eligible)
%DT_CONTROL One CAUSAL joint binary decision for all N devices.
% A token contains current state, PREVIOUS action/reward, requested RTG, stage.
% Neither the current target action nor its outcome is present in that token.
N=size(observation,1);
if isempty(runtime)
    runtime.tokens=zeros(0,model.net.input_size);
    runtime.previous_action=zeros(1,N); runtime.previous_reward=0;
    runtime.remaining_return=model.desired_return;
end
token=[reshape(observation',1,[]) runtime.previous_action ...
    runtime.previous_reward runtime.remaining_return model.stage];
runtime.tokens=[runtime.tokens;token];
if size(runtime.tokens,1)>model.net.context, runtime.tokens=runtime.tokens(end-model.net.context+1:end,:); end
L=model.net.context; X=zeros(L,model.net.input_size); valid=false(L,1);
rows=L-size(runtime.tokens,1)+1:L; X(rows,:)=runtime.tokens; valid(rows)=true;
z=dt_forward(model.net,X,valid);
scores=z(end,:)';
threshold=0;
if isfield(model,'action_threshold')
    threshold=log(model.action_threshold/(1-model.action_threshold));
end
if model.stage==1 && isfield(model,'positive_weight'), scores=scores-log(model.positive_weight); end
action=(scores>=threshold) & eligible(:);
runtime.current_action=action(:)';
end
