function z = grid2world(zGrid,range,params)
% GRID2WORLD    converts stimuli from grid to world coordinates
%   GRID2WORLD performs the common transformation of the stimulus from its
%   coordinates in the grid (1:N) to its true (world) representation   

%-------------------------------------------------------------------------%
% Revised: 08/24/16
%   -changed to expect inputs (zGrid) and outputs (z) in the JGMSTD format,
%   i.e. Nexamples x Ndims---in accordance with parallel changes to
%   scalefxn.m.
% Revised: 07/03/14
%   -made a meaningless change
% Created: 11/30/10
%   by JGM
%-------------------------------------------------------------------------%

% extract useful params
N = params.N;
oo = ones(size(zGrid,2),1);
patchmin = params.margin*oo;
patchmax = patchmin + params.respLength;

% convert x: grid -> patch -> world
zPatch = scalefxn(zGrid,oo,N*oo,0*oo,params.gridsize*oo);
z = scalefxn(zPatch,patchmin,patchmax,range(:,1),range(:,2));

end