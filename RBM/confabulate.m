function confabs = confabulate(wts,params,varargin)
% CONFABULATE   Makes a DBN dream
%   CONFABULATE confabulates images, given a DBN (wts, params).  It also
%   takes optinal arguments to specify the number of samples ('nSamples')
%   and length of the burn in ('nBurn')

%-------------------------------------------------------------------------%
% Revised: 05/10/11
%   -adapted to incorporate updown2.m
% Revised: 09/30/10
%   -added varargin in
% Revised: 09/28/10
%   -updated to match changes in counterpart files (e.g. flexibility in
%   layer unit type)
% Created: 06/18/10
%   by JGM
%-------------------------------------------------------------------------%

% remove me??
wrkspc4;
for j = 1:length(params.mods)
    h = figure(j); hold on;
    ahandle(j) = get(h,'CurrentAxes');
    % set(h,'position',[1450 552 560 420]); % [1665 377 560 420])
    % set(h,'position',[1450 45 560 420]); % [2375 371 560 420])
end
smin = params.smin;
smax = params.smax;
range = smax - smin;
Nmods = length(params.mods);
PLOT = 1;

% init
nBurn = 100;
nSamples = 5000;
EFHwts = wts(end/2:end/2+1);
EFHparams = params;
EFHparams.N = params.N;                         % *** see (1) ***
EFHparams.numsUnits = params.numsUnits(end-1:end);
EFHparams.typeUnits = params.typeUnits(end-1:end);
%%% L = size(RBMwts{1},2);
typeUnits = params.typeUnits;
numsUnits = params.numsUnits;
topDstrbs = typeUnits{end};
topNums = numsUnits{end};
Ntrials = params.Ntrials;

% randomly intialize deepest layer
endinds = cumsum(numsUnits);
startinds = [1, endinds(1:end-1)+1];
for iGrp = 1:length(topDstrbs)
    switch typeUnits{end}                           % init data (row vec!)
        case 'Bernoulli'
            topstates(startinds(iGrp):endinds(iGrp)) =...
                zeros(1,topNums(iGrp)); % double(rand(1,L)>1);
            % zeros(1,L);
            % round(rand(1,L));
        case 'Binomial'
            topstates(startinds(iGrp):endinds(iGrp)) =...
                sum(round(rand([topNums(iGrp),Ntrials])),3);
            % topstates = sum(round(rand(1,[L,n])),3);
        case 'Poisson'
            g = mean(mean([params.gmin; params.gmax]));
            %%% topstates = poissrnd(g*0.5,L);
            topstates(startinds(iGrp):endinds(iGrp)) =...
                ignpoi(g*0.5,topNums(iGrp));
        otherwise
            error('strange unit types! -- jgm');
    end
end
penstates = invParamMap(topstates,EFHwts{2}(1:end-1,:),EFHwts{2}(end,:),...
    EFHparams.typeUnits{2},EFHparams.numsUnits{2},EFHparams);

% get varargs
for i=1:2:length(varargin)
    switch varargin{i}
        case 'nSamples'
            nSamples = varargin{i+1};
        case 'nBurn'
            nBurn = varargin{i+1};
        case 'initdata'
            bottomstates = varargin{i+1};
            states = bottomstates;
            for layer = 1:length(wts)/2-1
                means = invParamMap(states,wts{layer}(1:end-1,:),...
                    wts{layer}(end,:),typeUnits{layer+1},...
                    numsUnits{layer+1},params);
                states = sampleT(means,typeUnits{layer+1},...
                    numsUnits{layer+1},params);
            end
            penstates = states;
        otherwise
            error('unrecognized option for confabulate.m\n');
    end
end


% get estimators
T = displayshape(penstates,params);
for k = 1:Nmods
    shatL(:,k) = decode(T{k},[smin(:,k) smax(:,k)],params,'CoM');
end


% cycle through samples
confabs = zeros(nSamples,params.numsUnits(1));
h = figure(3);
% set(h,'position',[2361 469 560 420]);
EDGE = zeros(Nmods,1);
for j = 1:nSamples
    
    % Gibbs sample for awhile from the autoencoder
    i=1;
    while i<=nBurn
        caca = 0;
        pennew = updownDBN(penstates,EFHwts,params,'suffstats','quiet');
        % *** see (1) ***
        
        % check for bad points
        T = displayshape(pennew,params);
        BAD = zeros(1,Nmods);
        for k = 1:Nmods
            
            shatL(:,k,1) = decode(T{k},[smin(:,k) smax(:,k)],params,'CoM');
            LOW = sum(sum(T{k}(:)) < 110);
            if sum(T{k}(:)) < 5 % 80
                penstates = states;
                fprintf('all zeros; resetting to last confab -- jgm\n');
                caca = 1;
                % pause()
                break
            end
%             if EDGE(k)
%                 fprintf('.');
%             end

            if LOW && EDGE(k)
                sum(T{k}(:))
                if PLOT
                    figure(3);
                    PPCplot(cat(2,T{:}),params,[i]);
                    drawnow;
                end
                
                Told = displayshape(penstates,params);
                axes(ahandle(k));
                scatter(squeeze(shatL(1,k,1)),squeeze(shatL(2,k,1)),'kx');
                
%                 fprintf('probably a bad sample; discard? ');
%                 reply = input('y/n ','s');
%                 BAD = strcmp(reply,'y');
                BAD(k) = BAD(k) + 1;
                fprintf('%d probably a bad sample; discarding...\n',BAD(k));
                sum(penstates)
                if BAD(k) > 100
                    error('Too many bad samples in a row -- jgm');
                end
            end
            
            EDGE(k) = sum(abs(shatL(:,k,1) - smin(:,k)) < 0.05*range(:,k)) ||...
                      sum(abs(smax(:,k) - shatL(:,k,1)) < 0.05*range(:,k));
            
        end
        
        if ~sum(BAD) && ~caca
            penstates = pennew;
            i=i+1;
        end
                
    end
    states = penstates;
    
    % plot this sample
    if PLOT
        figure(3);
        PPCplot(cat(2,T{:}),params,[i]);
        drawnow;
        for k = 1:Nmods
            axes(ahandle(k));
            plot(squeeze(shatL(1,k,:)),squeeze(shatL(2,k,:)),'g');
        end
    end
    shatL(:,:,2) = shatL(:,:,1);
    
    
%     % pass these data down through each layer to the "output"
%     for layer = (length(wts)/2+2):length(wts)
%         means = invParamMap(states,wts{layer}(1:end-1,:),...
%             wts{layer}(end,:),typeUnits{length(wts)-layer+1},params);
%         states = sampleT(means,typeUnits{length(wts)-layer+1},params);
%     end
     confabs(j,:) = states;
     
end

end
%-------------------------------------------------------------------------%
%-------------------------------------------------------------------------%



%-------------------------------------------------------------------------%
function grottest(params)




end
%-------------------------------------------------------------------------%

% *** (1) ***
% The plotting fxn as it's written doesn't make much sense if the
% penultimate layer isn't actually the input layer; so while theoretically
% you could change RBMparams.N to something other than params.N, you won't,
% b/c you won't be plotting anything in these cases.