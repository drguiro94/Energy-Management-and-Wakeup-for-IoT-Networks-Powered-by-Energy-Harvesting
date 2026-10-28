function [m,trace,policy] = simulate_network(cfg,s,policy,training)
%SIMULATE_NETWORK Common simulator for every policy; no globals or MAT inputs.
% In each TTI: choose duty state -> pay idle/WuR -> sense/report -> optionally
% request extra reports -> harvest. WuR requests are intra-slot subactions:
% no extra ambient harvest or second event is generated during that exchange.
% Actual energy, requested energy, clipping loss, and information are separate.
if nargin<4, training=false; end
clock_start=tic; N=size(s.dev,1); K=numel(s.event_occurs);
dx=bsxfun(@minus,s.dev(:,1),s.dev(:,1)');
dy=bsxfun(@minus,s.dev(:,2),s.dev(:,2)'); D=sqrt(dx.^2+dy.^2);
neighbors=double(D<=cfg.active_distance & ~eye(N));
battery=s.initial_battery(:); estimate=battery;
last_score=zeros(N,1); last_delta=false(N,1); last_info=0;
tot=zeros(1,17); % See the explicit metric assignments at the end.
max_budget_error=0; battery_at_measurement_start=battery;
prev_state=[]; prev_action=[]; prev_reward=0; reward_sum=0;
two_stage=any(strcmp(policy.type,{'rl','dt'}));
collect=isfield(cfg,'collect_learning') && cfg.collect_learning;
pending_wake=[]; wake_reward_sum=0; wake_decisions=0;
dt_idle_runtime=[]; dt_wake_runtime=[];
record=cfg.capture_trace && ~training;
trace=struct();
if collect
    experience.idle.state=zeros(K,8*N); experience.idle.action=zeros(K,N);
    experience.idle.reward=zeros(K,1); experience.idle.eligible=true(K,N);
    experience.idle.feedback_reward=zeros(K,1);
    experience.wake.state=zeros(K,8*N); experience.wake.action=zeros(K,N);
    experience.wake.reward=zeros(K,1); experience.wake.eligible=false(K,N);
    wake_logged=0;
end
if record
    J=min(cfg.trace_devices,N);
    trace.time=(1:K)*cfg.TTI;
    trace.battery=zeros(J,K); trace.mean_battery=zeros(1,K);
    trace.low_energy=zeros(1,K); trace.state=4*ones(J,K);
    trace.info=zeros(1,K); trace.energy_actual=zeros(1,K);
    trace.energy_requested=zeros(1,K); trace.harvest=zeros(1,K);
    trace.wakes=zeros(1,K); trace.dev=s.dev;
end

for k=1:K
    if k==cfg.burn_in+1, battery_at_measurement_start=battery; end
    old=battery; measured=k>cfg.burn_in;
    if two_stage || collect
        observation=learning_observation(s.dev,estimate,last_score,last_info,...
            neighbors*double(last_delta),last_delta,cfg);
    end
    wake_decision=false; wake_action=false(N,1); wake_eligible=false(N,1);
    wake_credit=zeros(N,1); initial_report_information=0;
    %% Duty cycling uses past observations only (except the explicit genie).
    if strcmp(policy.type,'rl')
        local=q_state(estimate,last_score,last_info,neighbors*double(last_delta),last_delta,N,cfg);
        if training && ~isempty(prev_state)
            policy.q_idle=shared_q_update(policy.q_idle,prev_state,prev_action,...
                prev_reward+cfg.rl.discount*max(policy.q_idle(local,:),[],2),cfg.rl.learning_rate);
        end
        [~,action]=max(policy.q_idle(local,:),[],2);
        constrained=isfield(policy,'control') && ...
            (~strcmp(policy.control.mode,'independent') || policy.control.energy_guard);
        if (training || isfield(policy,'behaviour_epsilon')) && ~constrained
            epsilon=policy.epsilon;
            if isfield(policy,'behaviour_epsilon'), epsilon=policy.behaviour_epsilon; end
            explore=rand(N,1)<epsilon;
            action(explore)=randi(2,sum(explore),1);
        end
        planned=action==2; idle=planned & battery>=cfg.idle_E;
        if constrained
            exploration=0;
            if training, exploration=policy.epsilon; end
            if isfield(policy,'behaviour_epsilon'), exploration=policy.behaviour_epsilon; end
            planned=learning_idle_actions(policy.q_idle(local,2)-policy.q_idle(local,1),...
                estimate,k,policy.control,exploration);
            action=1+double(planned); idle=planned & battery>=cfg.idle_E;
        end
    elseif strcmp(policy.type,'dt')
        [planned,dt_idle_runtime,idle_scores]=dt_control(policy.dt.idle,observation,dt_idle_runtime,true(N,1));
        if isfield(policy,'control') && ~strcmp(policy.control.mode,'independent')
            planned=learning_idle_actions(idle_scores,estimate,k,policy.control,0);
            dt_idle_runtime.current_action=planned';
        elseif isfield(policy,'control') && policy.control.energy_guard
            planned=planned & estimate>=policy.control.minimum_energy;
            dt_idle_runtime.current_action=planned';
        end
        idle=planned & battery>=cfg.idle_E;
    elseif strcmp(policy.type,'q_reference')
        local=q_state(estimate,last_score,last_info,neighbors*double(last_delta),last_delta,N,cfg);
        if training && ~isempty(prev_state)
            policy.q=q_update(policy.q,prev_state,prev_action,...
                prev_reward+cfg.rl.discount*max(policy.q(local,:),[],2),cfg.rl.learning_rate);
        end
        [~,action]=max(policy.q(local,:),[],2);
        if training
            explore=rand(N,1)<policy.epsilon;
            action(explore)=randi(2,sum(explore),1);
        end
        planned=action==2;
        idle=planned & battery>=cfg.idle_E;
    elseif strcmp(policy.type,'genie')
        planned=false(N,1);
        if s.event_occurs(k)
            distances=sqrt(sum(bsxfun(@minus,s.dev,s.event_position(k,:)).^2,2));
            [near,j]=min(distances);
            if near<=cfg.active_distance, planned(j)=true; end
        end
        idle=planned & battery>=cfg.idle_E;
        if cfg.genie_ignore_battery, idle=planned; end
    else
        planned=mod(k-1+policy.phase,policy.cycle)<policy.on_time;
        idle=check_idle(k,policy.cycle,policy.on_time,policy.phase,battery,cfg);
    end
    if collect
        experience.idle.state(k,:)=reshape(observation',1,[]);
        experience.idle.action(k,:)=planned';
    end

    %% Routine state cost: idle/sensing circuitry or low-power WuR.
    state=4*ones(N,1); state(idle)=1;
    base=cfg.wake_up_Energy*ones(N,1); base(idle)=cfg.idle_E;
    [battery,paid_base]=update_battery_harvest(battery,base,zeros(N,1),cfg);
    % BS estimator: subtract planned costs, add MEAN harvested energy later.
    % This is a simple mean predictor, not the unpublished battery estimator.
    known_base=cfg.wake_up_Energy*ones(N,1); known_base(planned)=cfg.idle_E;
    estimate=max(0,estimate-known_base);
    requested=sum(base); paid_idle=sum(paid_base(idle));
    paid_sleep=sum(paid_base(~idle)); paid_tx=0; paid_wake=0;
    wrong=0; opportunities=0; wasted=0; wake_count=0; total_info=0;
    info=zeros(N,1); successful=false(N,1);

    if s.event_occurs(k)
        if isempty(s.detect_uniform), u=zeros(N,1); else, u=s.detect_uniform(:,k); end
        [can_sense,potential_all]=check_active(s.dev,s.event_position(k,:),...
            cfg.active_distance,true(N,1),cfg,u);
        attempt=idle & can_sense; potential=potential_all.*idle;
        if strcmp(policy.type,'genie'), attempt=idle; end
        [success,battery,spent]=update_battery_active(battery,attempt,cfg);
        if strcmp(policy.type,'genie') && cfg.genie_ignore_battery, success=attempt; end
        state(attempt)=2; state(success)=3;
        info=potential.*success; successful=success;
        estimate=max(0,estimate-cfg.Tx_E*double(success));
        paid_tx=paid_tx+sum(spent); requested=requested+cfg.Tx_E*sum(attempt);
        wrong=sum(attempt & ~success); opportunities=sum(attempt);
        wasted=sum(spent(attempt & ~success));
        total_info=aggregate_information(info,cfg);
        initial_report_information=total_info;

        %% BS requests follow a real received report, never an unseen event.
        allow_wake=any(info>0) && any(strcmp(policy.type,{'cluster','adjusted','q_reference','rl','dt'}));
        excluded=idle; % Already-awake devices are never requested again.
        target=policy.target;
        if strcmp(policy.type,'q_reference'), target=cfg.Psi; end
        if two_stage && allow_wake
            % Joint binary extra-report decision, Eq. (25). A true event
            % location or a future report outcome is never an input.
            excluded=planned;
            [initial_order,initial_score]=wake_close_device(D,info,excluded,cfg,policy.lookup);
            if isfield(policy,'control') && policy.control.energy_guard
                initial_order=initial_order(estimate(initial_order)>=policy.control.minimum_energy);
            end
            wake_eligible(initial_order)=true;
            wake_observation=learning_observation(s.dev,estimate,initial_score,total_info,...
                neighbors*double(planned),planned,cfg);
            if any(wake_eligible)
                wake_decision=true;
                if strcmp(policy.type,'rl')
                    wake_state=q_state(estimate,initial_score,total_info,...
                        neighbors*double(planned),planned,N,cfg);
                    if training && ~isempty(pending_wake)
                        next_value=max(policy.q_wake(wake_state,:),[],2).*wake_eligible;
                        mask=pending_wake.mask;
                        previous_reward=pending_wake.reward;
                        if ~isscalar(previous_reward), previous_reward=previous_reward(mask); end
                        policy.q_wake=shared_q_update(policy.q_wake,pending_wake.state(mask),...
                            pending_wake.action(mask),previous_reward+...
                            cfg.rl.wake_discount*next_value(mask),cfg.rl.learning_rate);
                    end
                    [~,wake_binary]=max(policy.q_wake(wake_state,:),[],2);
                    if training || isfield(policy,'behaviour_epsilon')
                        epsilon=policy.epsilon;
                        if isfield(policy,'behaviour_epsilon'), epsilon=policy.behaviour_epsilon; end
                        explore=(rand(N,1)<epsilon) & wake_eligible;
                        wake_binary(explore)=randi(2,sum(explore),1);
                    end
                    wake_action=(wake_binary==2) & wake_eligible;
                else
                    [wake_action,dt_wake_runtime]=dt_control(policy.dt.wake,wake_observation,...
                        dt_wake_runtime,wake_eligible);
                end
            end
            request_order=initial_order(wake_action(initial_order));
            request_index=1; target=Inf;
        end
        while allow_wake && total_info<target
            if two_stage
                if request_index>numel(request_order), break; end
                j=request_order(request_index); request_index=request_index+1;
            else
                [order,score]=wake_close_device(D,info,excluded,cfg,policy.lookup);
                if isempty(order), break; end
                j=order(1);
            end
            if strcmp(policy.type,'q_reference')
                % NEW reference: a greedy marginal-value wake rule, not the
                % paper's absent second-stage learned binary policy.
                gain=max(0,cfg.Psi*score(j)-total_info);
                if cfg.rl.mu2*gain<=1/N, break; end
            end
            excluded(j)=true; wake_count=wake_count+1;
            information_before_request=total_info;
            opportunities=opportunities+1;
            [battery(j),wake_spent]=update_battery_harvest(battery(j),cfg.idle_E,0,cfg);
            paid_wake=paid_wake+sum(wake_spent); requested=requested+cfg.idle_E;
            estimate(j)=max(0,estimate(j)-cfg.idle_E);
            try_tx=can_sense(j);
            [ok,battery(j),spent]=update_battery_active(battery(j),try_tx,cfg);
            requested=requested+cfg.Tx_E*sum(try_tx); paid_tx=paid_tx+sum(spent);
            info(j)=potential_all(j)*ok; successful(j)=ok;
            state(j)=2; if ok, state(j)=3; end
            estimate(j)=max(0,estimate(j)-cfg.Tx_E*ok);
            if ~ok
                wrong=wrong+1; wasted=wasted+sum(wake_spent)+sum(spent);
            end
            total_info=aggregate_information(info,cfg);
            wake_credit(j)=cfg.rl.mu2*(total_info-information_before_request)-1/N;
        end
        if wake_decision
            star_reward=cfg.rl.mu2*total_info-wake_count/N; % Eq. (25)
            wake_reward_sum=wake_reward_sum+star_reward; wake_decisions=wake_decisions+1;
            if training && strcmp(policy.type,'rl')
                pending_wake.state=wake_state; pending_wake.action=1+double(wake_action);
                pending_wake.mask=wake_eligible; pending_wake.reward=star_reward;
                if strcmp(cfg.rl.wake_credit,'incremental'), pending_wake.reward=wake_credit; end
            elseif strcmp(policy.type,'dt')
                dt_wake_runtime=dt_feedback(policy.dt.wake,dt_wake_runtime,star_reward);
            end
            if collect
                wake_logged=wake_logged+1;
                experience.wake.state(wake_logged,:)=reshape(wake_observation',1,[]);
                experience.wake.action(wake_logged,:)=wake_action';
                experience.wake.eligible(wake_logged,:)=wake_eligible';
                experience.wake.reward(wake_logged)=star_reward;
            end
            if abs(sum(wake_credit)-(star_reward-cfg.rl.mu2*initial_report_information))>1e-9
                error('Incremental wake credit does not preserve the event objective.');
            end
        end
        % Only reported strengths enter future practical policy features.
        if (two_stage || collect || strcmp(policy.type,'q_reference')) && any(successful)
            [~,last_score]=wake_close_device(D,info,false(N,1),cfg,policy.lookup);
        elseif two_stage || collect || strcmp(policy.type,'q_reference')
            last_score=cfg.rl.score_decay*last_score;
        end
        last_info=total_info;
    else
        last_score=cfg.rl.score_decay*last_score;
        last_info=cfg.rl.score_decay*last_info;
    end

    %% EH at the end of the TTI, Eq. (7), followed by a conservation check.
    harvest=cfg.E_B*double(s.harvest(:,k));
    [battery,~,overflow]=update_battery_harvest(battery,zeros(N,1),harvest,cfg);
    if strcmp(cfg.harvest_model,'bernoulli_fixed')
        mean_h=cfg.E_B*(-expm1(-cfg.lambda*cfg.TTI));
    else
        mean_h=cfg.E_B/2;
    end
    estimate=min(cfg.E_max,estimate+mean_h);
    spent_total=paid_idle+paid_sleep+paid_tx+paid_wake;
    balance=sum(old)+sum(harvest)-spent_total-sum(overflow)-sum(battery);
    max_budget_error=max(max_budget_error,abs(balance));
    if any(battery < -1e-9 | battery > cfg.E_max+1e-9) || abs(balance)>1e-7*N
        error('Battery or energy-conservation failure at TTI %d.',k);
    end
    reward=idle_task_reward(total_info,s.event_occurs(k),sum(planned),N,cfg);
    feedback_reward=reward;
    if isfield(cfg.rl,'reward_mode') && strcmp(cfg.rl.reward_mode,'information_detection')
        % The BS cannot distinguish a missed event from no event. Use only
        % received information and known commands in online DT history.
        % Privileged missed-event labels remain OFFLINE reward targets.
        feedback_reward=cfg.rl.mu2*total_info/cfg.Psi-cfg.rl.sensing_penalty*sum(planned)/N;
    elseif isfield(cfg.dt,'observable_feedback') && cfg.dt.observable_feedback
        feedback_reward=1-sum(planned)/N;
    end
    reward_sum=reward_sum+reward;
    if training && strcmp(policy.type,'q_reference')
        prev_state=local; prev_action=action; prev_reward=reward;
    elseif training && strcmp(policy.type,'rl')
        prev_state=local; prev_action=action; prev_reward=reward;
    elseif strcmp(policy.type,'dt')
        dt_idle_runtime=dt_feedback(policy.dt.idle,dt_idle_runtime,feedback_reward);
    end
    if collect
        experience.idle.reward(k)=reward;
        experience.idle.feedback_reward(k)=feedback_reward;
    end
    last_delta=planned;
    if measured
        % [info events misses lowB meanB actual requested idle sleep tx wake
        %  wrong opportunities wasted rawEH overflow wakeRequests]
        tot=tot+[total_info s.event_occurs(k) double(s.event_occurs(k) && total_info==0)...
            mean(battery<cfg.Tx_E) mean(battery) spent_total requested...
            paid_idle paid_sleep paid_tx paid_wake wrong opportunities wasted...
            sum(harvest) sum(overflow) wake_count];
    end
    if record
        trace.battery(:,k)=battery(1:J); trace.mean_battery(k)=mean(battery);
        trace.low_energy(k)=mean(battery<cfg.Tx_E); trace.state(:,k)=state(1:J);
        trace.info(k)=total_info; trace.energy_actual(k)=spent_total/N;
        trace.energy_requested(k)=requested/N; trace.harvest(k)=mean(harvest);
        trace.wakes(k)=wake_count;
    end
end
if training && strcmp(policy.type,'q_reference') && ~isempty(prev_state)
    policy.q=q_update(policy.q,prev_state,prev_action,prev_reward,cfg.rl.learning_rate);
elseif training && strcmp(policy.type,'rl') && ~isempty(prev_state)
    policy.q_idle=shared_q_update(policy.q_idle,prev_state,prev_action,prev_reward,cfg.rl.learning_rate);
    if ~isempty(pending_wake)
        mask=pending_wake.mask;
        previous_reward=pending_wake.reward;
        if ~isscalar(previous_reward), previous_reward=previous_reward(mask); end
        policy.q_wake=shared_q_update(policy.q_wake,pending_wake.state(mask),...
            pending_wake.action(mask),previous_reward,cfg.rl.learning_rate);
    end
end
if collect
    experience.wake.state=experience.wake.state(1:wake_logged,:);
    experience.wake.action=experience.wake.action(1:wake_logged,:);
    experience.wake.reward=experience.wake.reward(1:wake_logged);
    experience.wake.eligible=experience.wake.eligible(1:wake_logged,:);
    trace.learning=experience;
end

den=N*cfg.total; ne=tot(2);
m.info_per_event=safe_divide(tot(1),ne);
m.info_per_expected_event=safe_divide(tot(1),cfg.alpha*cfg.total); % Eq. (18)
m.misdetection=safe_divide(tot(3),ne);
m.low_energy=tot(4)/cfg.total; m.mean_battery=tot(5)/cfg.total;
m.energy_actual=tot(6)/den; m.energy_requested=tot(7)/den;
m.idle_energy=tot(8)/den; m.sleep_energy=tot(9)/den;
m.tx_energy=tot(10)/den; m.wake_energy=tot(11)/den;
m.wrong_per_event=safe_divide(tot(12),ne);
m.wrong_percent=100*safe_divide(tot(12),tot(13));
m.wasted_energy_per_device_event=safe_divide(tot(14),N*ne);
m.harvest_raw=tot(15)/den; m.harvest_overflow=tot(16)/den;
m.harvest_stored=(tot(15)-tot(16))/den;
m.net_raw=m.harvest_raw-m.energy_actual;
m.net_stored=m.harvest_stored-m.energy_actual;
m.wakes_per_event=safe_divide(tot(17),ne);
m.battery_change=sum(battery-battery_at_measurement_start)/den;
m.event_count=ne; m.miss_count=tot(3); m.activation_count=tot(13);
m.wrong_count=tot(12); m.information_sum=tot(1);
m.budget_error=max_budget_error; m.reward=reward_sum/K;
m.wake_reward=wake_reward_sum/max(1,wake_decisions); m.wake_decision_count=wake_decisions;
m.elapsed_seconds=toc(clock_start);
m.final_battery=battery;
end

function value=safe_divide(a,b)
if b==0, value=NaN; else, value=a/b; end
end

function q=q_update(q,state,action,target,rate)
% Average simultaneous shared-table TD updates to avoid device-order bias.
if isscalar(target), target=target*ones(size(state)); end
linear=state+size(q,1)*(action-1);
delta=target(:)-q(linear);
count=accumarray(linear,1,[numel(q) 1]);
change=accumarray(linear,delta,[numel(q) 1]);
used=find(count); q(used)=q(used)+rate*change(used)./count(used);
end
