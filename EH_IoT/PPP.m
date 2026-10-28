function dev = PPP(A, B, N)
%PPP Uniform independent positions, conditional on exactly N devices.
dev = [A*rand(N,1), B*rand(N,1)];
end
