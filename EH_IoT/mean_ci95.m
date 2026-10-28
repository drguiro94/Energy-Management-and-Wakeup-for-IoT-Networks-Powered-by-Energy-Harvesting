function [mu,half,n] = mean_ci95(x)
%MEAN_CI95 Student-t interval across independent deployments, no toolbox.
% A single trial has no estimable between-deployment confidence interval.
x=x(isfinite(x)); n=numel(x);
if n==0, mu=NaN; half=NaN; return; end
mu=mean(x);
if n<2, half=NaN; return; end
nu=n-1; lo=0; hi=1000;
for k=1:60
    t=(lo+hi)/2;
    tail=0.5*betainc(nu/(nu+t*t),nu/2,0.5);
    if tail>0.025, lo=t; else, hi=t; end
end
half=(lo+hi)/2*std(x,0)/sqrt(n);
end
