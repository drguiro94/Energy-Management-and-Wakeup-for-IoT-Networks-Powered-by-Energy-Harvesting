function idle = check_idle(k,cycle,on_time,phase,battery,cfg)
%CHECK_IDLE A slot index actually advances the duty-cycle phase.
% Phases are integers in [0,L-1]. The ON window is [0,ell-1], Eq. (11).
% The supplied main loops passed TTI=1 instead of the advancing slot index.
idle = mod(k-1+phase(:),cycle(:)) < on_time(:);
% This is a LOCAL energy check; it does not give the BS hidden battery data.
idle = idle & battery(:)>=cfg.idle_E;
end
