function model = train_dt_stage(train,validation,cfg,seed,stage)
%TRAIN_DT_STAGE Offline causal sequence learning with Adam and early stopping.
% Entire episodes are held out BEFORE window sampling; overlapping windows
% from the same rollout never straddle the training/validation boundary.
rng(seed,'twister'); N=size(train{1}.Y,2);
net=dt_initialize(size(train{1}.X,2),N,cfg.dt); optimizer=[];
positive=0; negative=0;
for e=1:numel(train)
    mask=double(train{e}.action_mask); labels=train{e}.Y;
    positive=positive+sum(sum(mask.*labels));
    negative=negative+sum(sum(mask.*(1-labels)));
end
positive_weight=1;
if cfg.dt.balance_classes && positive>0
    positive_weight=max(1,min(cfg.dt.maximum_positive_weight,negative/positive));
end
valid_windows=cell(cfg.dt.validation_windows,1);
for k=1:numel(valid_windows)
    e=mod(k-1,numel(validation))+1; T=size(validation{e}.X,1);
    endpoint=max(1,ceil(k/numel(valid_windows)*T));
    [x,y,v,m]=dt_sequence_window(validation{e},endpoint,cfg.dt.context);
    valid_windows{k}={x,y,v,m};
end
history=NaN(cfg.dt.updates,3); best=Inf; best_net=net; stale=0;
checkpoints={}; best_update=0;
for it=1:cfg.dt.updates
    names=fieldnames(net.parameters); gradient=struct();
    for j=1:numel(names), gradient.(names{j})=zeros(size(net.parameters.(names{j}))); end
    batch_loss=0;
    for b=1:cfg.dt.batch_size
        e=randi(numel(train)); t=randi(size(train{e}.X,1));
        [x,y,v,m]=dt_sequence_window(train{e},t,cfg.dt.context);
        weights=double(m).*(1+(positive_weight-1)*y);
        [loss,g]=dt_loss_gradient(net,x,y,v,weights); batch_loss=batch_loss+loss/cfg.dt.batch_size;
        for j=1:numel(names), name=names{j}; gradient.(name)=gradient.(name)+g.(name)/cfg.dt.batch_size; end
    end
    [net,optimizer]=dt_adam_update(net,gradient,optimizer,cfg.dt.learning_rate,cfg.dt.gradient_clip);
    history(it,:)=[it batch_loss NaN];
    if mod(it,cfg.dt.validation_every)==0 || it==cfg.dt.updates
        loss=0;
        for k=1:numel(valid_windows)
            w=valid_windows{k}; weights=double(w{4}).*(1+(positive_weight-1)*w{2});
            loss=loss+dt_loss_gradient(net,w{1},w{2},w{3},weights)/numel(valid_windows);
        end
        history(it,3)=loss;
        if loss<best-cfg.dt.minimum_improvement*max(1e-8,abs(best)) || ~isfinite(best)
            best=loss; best_net=net; stale=0; best_update=it;
        else
            stale=stale+1;
        end
        if cfg.verbose && (it==cfg.dt.validation_every || it==cfg.dt.updates)
            fprintf('DT stage %d | update %d | train loss %.4f | held-out loss %.4f\n',stage,it,batch_loss,loss);
        end
        if isfield(cfg.dt,'rollout_selection') && cfg.dt.rollout_selection && ...
                (mod(it,cfg.dt.checkpoint_every)==0 || it==cfg.dt.updates || stale>=cfg.dt.patience)
            snapshot.net=net; snapshot.update=it; snapshot.validation_loss=loss;
            checkpoints{end+1}=snapshot; 
        end
        if stale>=cfg.dt.patience, break; end
    end
end
returns=[];
for e=1:numel(train), returns=[returns;train{e}.returns]; end 
returns=sort(returns);
quantile_index=max(1,min(numel(returns),ceil(cfg.dt.desired_return_quantile*numel(returns))));
model.net=best_net; model.stage=stage; model.discount=cfg.rl.discount;
model.desired_return=returns(quantile_index);
model.return_range=[min(returns) max(returns)];
model.training_history=history(1:it,:); model.validation_loss=best;
model.training_seed=seed;
model.positive_weight=positive_weight;
model.selected_checkpoint_update=best_update;
if ~isempty(checkpoints), model.checkpoints=checkpoints; end
if stage==1, model.action_threshold=cfg.dt.wake_threshold; else, model.action_threshold=0.5; end
end
