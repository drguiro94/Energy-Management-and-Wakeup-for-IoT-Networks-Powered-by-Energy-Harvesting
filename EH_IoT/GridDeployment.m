function dev = GridDeployment(A,B,N)
%GRIDDEPLOYMENT Return device positions (the original only drew a figure).
% For square N and a square area this is the centered grid used in Eq. (22).
nx = max(1,round(sqrt(N*A/B))); ny = ceil(N/nx);
[x,y] = meshgrid(((1:nx)-0.5)*A/nx, ((1:ny)-0.5)*B/ny);
dev = [x(:),y(:)]; dev = dev(1:N,:);
end
