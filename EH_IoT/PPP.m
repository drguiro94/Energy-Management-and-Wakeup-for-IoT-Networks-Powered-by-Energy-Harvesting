function dev = PPP(A, B, N)
%PPP Uniform independent positions, conditional on exactly N devices.
% This preserves the supplied function name. It does NOT draw a Poisson N.
dev = [A*rand(N,1), B*rand(N,1)];
end
