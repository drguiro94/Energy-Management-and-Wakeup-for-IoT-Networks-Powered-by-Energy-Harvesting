function [success,battery,paid] = update_battery_active(battery,attempt,cfg)
%UPDATE_BATTERY_ACTIVE Transmission succeeds only with Tx_E available now.
% Depleted attempts consume residual charge, but cannot deliver information.
attempt=logical(attempt(:)); battery=battery(:);
success = attempt & battery>=cfg.Tx_E;
paid = min(battery,cfg.Tx_E*double(attempt));
battery = battery-paid;
end
