function observation = learning_observation(dev,estimate,score,info,count,delta,cfg)
%LEARNING_OBSERVATION BS-observable state at a decision instant, Eq. (23).
% Eight features per device: estimated battery, reported/inferred score,
% received information, x, y, active-neighbor fraction, prior action, density.
% True unreported measurements, event position, and future EH are excluded.
N=size(dev,1);
observation=[estimate(:)/cfg.E_max score(:)/cfg.Psi ...
    (info/cfg.Psi)*ones(N,1) dev(:,1)/cfg.A dev(:,2)/cfg.B ...
    count(:)/max(1,N-1) double(delta(:)) (N/(cfg.A*cfg.B))*ones(N,1)];
end
