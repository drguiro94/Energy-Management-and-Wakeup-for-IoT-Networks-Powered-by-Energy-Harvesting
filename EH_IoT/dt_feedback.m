function runtime = dt_feedback(model,runtime,reward)
%DT_FEEDBACK Update desired discounted return using OBSERVED reward only.
runtime.previous_action=runtime.current_action;
runtime.previous_reward=reward;
runtime.remaining_return=(runtime.remaining_return-(1-model.discount)*reward)/max(model.discount,1e-8);
% Keep online conditioning within the training-data support.
runtime.remaining_return=max(model.return_range(1),min(model.return_range(2),runtime.remaining_return));
end
