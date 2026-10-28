function [battery,paid,overflow] = update_battery_harvest(old,demand,harvest,cfg)
%UPDATE_BATTERY_HARVEST Cost first, then EH, with finite-buffer clipping.
% This is the ordering in Eq. (7). Actions cannot borrow future harvested
% energy. A failed action consumes the remaining battery as stated in III-A.
% paid is ACTUAL drain; demand is tracked separately by the simulator.
old=old(:); demand=demand(:); harvest=harvest(:);
paid = min(old,demand);
after = old-paid;
overflow = max(0,after+harvest-cfg.E_max);
battery = min(cfg.E_max,after+harvest);
end
