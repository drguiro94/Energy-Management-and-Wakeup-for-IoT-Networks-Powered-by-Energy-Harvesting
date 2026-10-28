function value = aggregate_information(info,cfg)
%AGGREGATE_INFORMATION Eq. (2), Eq. (3), or the archive's uncapped sum.
switch cfg.aggregation
    case 'max', value=max([0;info(:)]);
    case 'sum_saturated', value=min(cfg.Psi,sum(info(:)));
    case 'sum', value=sum(info(:));
end
end
