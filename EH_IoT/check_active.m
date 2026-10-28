function [active,info] = check_active(dev,event,dmax,idle,cfg,u)
%CHECK_ACTIVE Sensing range and event information, Section II-A.
% 'range' matches the archive. 'bernoulli' also samples p(d), matching the
% probabilistic transition in Section IV. Successful reports carry Psi*p(d).
d = sqrt(sum(bsxfun(@minus,dev,event).^2,2));
p = exp(-cfg.eta*d);
active = logical(idle(:)) & d<=dmax;
if strcmp(cfg.detection_model,'bernoulli'), active=active & u(:)<p; end
info = cfg.Psi*p.*active;
end
