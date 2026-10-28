function [X,Y,valid,mask] = dt_sequence_window(trajectory,endpoint,context)
%DT_SEQUENCE_WINDOW A causal context ending at an observed decision instant.
% Left padding is masked in attention, in the loss, and in action eligibility.
T=size(trajectory.X,1); assert(endpoint>=1 && endpoint<=T,'Invalid window endpoint.');
first=max(1,endpoint-context+1); count=endpoint-first+1;
X=zeros(context,size(trajectory.X,2)); Y=zeros(context,size(trajectory.Y,2));
valid=false(context,1); mask=false(size(Y));
destination=context-count+1:context; source=first:endpoint;
X(destination,:)=trajectory.X(source,:); Y(destination,:)=trajectory.Y(source,:);
valid(destination)=true; mask(destination,:)=trajectory.action_mask(source,:);
end
