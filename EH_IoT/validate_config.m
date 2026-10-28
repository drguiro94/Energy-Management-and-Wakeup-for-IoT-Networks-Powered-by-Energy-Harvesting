function validate_config(c)
%VALIDATE_CONFIG Fail early for invalid model inputs.
assert(c.A>0 && c.B>0 && c.TTI>0, 'Area and TTI must be positive.');
assert(c.alpha>=0 && c.alpha<=1 && isscalar(c.alpha), 'alpha must be in [0,1].');
assert(c.lambda>=0 && isfinite(c.lambda), 'lambda must be finite and nonnegative.');
assert(c.E_B>=0 && c.E_max>0, 'Invalid harvested energy or capacity.');
assert(c.Tx_E>0 && c.idle_E>0 && c.wake_up_Energy>=0, 'Invalid energy costs.');
assert(c.eta>=0 && c.Psi>0 && c.active_distance>0, 'Invalid sensing parameters.');
assert(all(c.N_values>=1 & c.N_values==floor(c.N_values)), 'N must be positive integers.');
assert(c.MCarlo>=1 && c.MCarlo==floor(c.MCarlo), 'MCarlo must be a positive integer.');
assert(c.total>=1 && c.total==floor(c.total), 'total must be a positive integer.');
assert(c.burn_in>=0 && c.burn_in==floor(c.burn_in), 'burn_in must be a nonnegative integer.');
assert(all(c.random_cycles>=1 & c.random_cycles==floor(c.random_cycles)), 'Invalid random cycles.');
assert(all(c.random_on_times>=1 & c.random_on_times==floor(c.random_on_times)), 'Invalid random ON times.');
assert(all(c.adjusted_cycles>=1 & c.adjusted_cycles==floor(c.adjusted_cycles)), 'Invalid search cycles.');
assert(all(c.adjusted_on_times>=1 & c.adjusted_on_times==floor(c.adjusted_on_times)), 'Invalid search ON times.');
assert(c.search_total>=1 && c.search_MCarlo>=1, 'Pilot sizes must be positive.');
assert(any(strcmp(c.harvest_model,{'bernoulli_fixed','uniform'})), 'Unknown EH model.');
assert(any(strcmp(c.detection_model,{'range','bernoulli'})), 'Unknown detection model.');
assert(any(strcmp(c.aggregation,{'max','sum_saturated','sum'})), 'Unknown aggregation rule.');
assert(any(strcmp(c.deployment,{'uniform','grid'})), 'Unknown deployment type.');
assert(all(ismember(c.methods,{'random','adjusted','cluster','genie','q_reference','rl','dt'})), 'Unknown policy.');
if any(ismember(c.methods,{'rl','dt'}))
    assert(c.rl.episodes>=1 && c.rl.steps>=1,'RL training budget must be positive.');
    assert(c.rl.learning_rate>0 && c.rl.learning_rate<=1,'Invalid Q learning rate.');
    assert(c.rl.discount>=0 && c.rl.discount<1,'Discount must lie in [0,1).');
    assert(any(strcmp(c.rl.action_mode,{'independent','cluster_rank','coverage_rank'})),'Unknown RL action mode.');
    if strcmp(c.rl.validation_metric,'information_detection')
        assert(isfinite(c.objective.miss_weight) && c.objective.miss_weight>=0,'Miss weight must be nonnegative.');
    end
    if strcmp(c.rl.action_mode,'coverage_rank')
        assert(c.rl.coverage_grid>=2 && c.rl.coverage_grid==floor(c.rl.coverage_grid),'Invalid coverage grid.');
        assert(c.rl.learned_weight>=0 && c.rl.energy_weight>=0,'Invalid action decoder weights.');
    end
end
if any(strcmp(c.methods,'dt'))
    assert(c.dt.context>=1 && c.dt.blocks>=1 && c.dt.heads>=1,'Invalid transformer architecture.');
    assert(mod(c.dt.d_model,c.dt.heads)==0,'d_model must be divisible by heads.');
    assert(c.dt.data_episodes>=3,'Use at least two training episodes and one held-out episode.');
    assert(c.dt.updates>=1 && c.dt.batch_size>=1,'Invalid DT training budget.');
    assert(any(strcmp(c.dt.action_mode,{'independent','cluster_rank','coverage_rank'})),'Unknown DT action mode.');
    if isfield(c.dt,'rollout_selection') && c.dt.rollout_selection
        assert(c.dt.rollout_validation_steps>=1 && c.dt.rollout_validation_trials>=1,'Invalid DT rollout budget.');
        assert(c.dt.checkpoint_every>=1,'Invalid DT checkpoint interval.');
        assert(c.dt.wake_threshold>0 && c.dt.wake_threshold<1,'Wake threshold must be in (0,1).');
    end
end
if isnumeric(c.initial_battery)
    assert(isscalar(c.initial_battery) && c.initial_battery>=0 && c.initial_battery<=c.E_max, 'Invalid initial battery.');
else
    assert(strcmp(c.initial_battery,'uniform'), 'Unknown initial battery model.');
end
end
