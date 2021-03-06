function smpls = ignpoi(mus)
% ignpoi    Poisson sampler
%   ignpoi (Integer GeNerate POIsson) generates an array of Poisson random 
%   deviates, smpls, with means given by the array mus.
%
%  Licensing:
%
%    This code is distributed under the GNU LGPL license.
%
%  Reference:
%
%    Joachim Ahrens, Ulrich Dieter,
%    Computer Generation of Poisson Deviates
%       From Modified Normal Distributions,
%    ACM Transactions on Mathematical Software,
%    Volume 8, Number 2, June 1982, pages 163-179.
%
%   Current version: JGM

%-------------------------------------------------------------------------%
% Amended: 03/17/14 (jgm)
%   -replaced r4_uniform_01 -> rand, snorm -> randn
% Vectorized: 03/18/14
%   by J.G. Makin
% Ported: 04/01/13
%   to Matlab
%   by John Burkhardt
% Created: 06/72
%   in FORTRAN77
%   by Barry Brown, James Lovato
% Written: 06/82
%   by Joachim Ahrens & Ulrich Dieter
%-------------------------------------------------------------------------%


%%%%%%%%%%%%%%%%%%%%%
% TO DO:
% (8) pass around the params to keep from having to keep computing them?
%%%%%%%%%%%%%%%%%%%%%


% vectorize (makes life simpler)
mudims = size(mus);
mus = mus(:);
smpls = zeros(size(mus));


% get variates, differently for means above and below 10
iSmall = (mus < 10.0);
if any(iSmall)
    smpls(iSmall) = getSamplesForSmallMu(mus(iSmall));
end
if ~all(iSmall)
    smpls(~iSmall) = getSamplesForBigMu(mus(~iSmall));
end

% reshape to original dimensioins
smpls = reshape(smpls,mudims);



end
%-------------------------------------------------------------------------%
%-------------------------------------------------------------------------%



%-------------------------------------------------------------------------%
function smpls = getSamplesForSmallMu(mus)
% Start new table and calculate p0.

% M = max(1, floor(mus));        %%% this appears unnecessary!
% L = 0;                        %%% this appears unnecessary!
p = exp(-mus);

% uniform sample for inversion method.
u = rand(size(mus));

% recurse until you've sampled for all entries in muSmall
smpls = getPoisCumProbLoopB(mus,u,p,p);
 %smpls = getPoisCumProbRecurse(mus,u,p,p,0);


end
%-------------------------------------------------------------------------%




%-------------------------------------------------------------------------%
function smpls = getPoisCumProbLoopC(mus,u,q,p)

Nmin = 0;
Nmax = 35;
smpls = sum(u > p.*cumsum((mus.^(Nmin:Nmax))./factorial(Nmin:Nmax),2),2);



% % init
% smpls = zeros(size(mus));
% youCanStopPrev = (u <= q);
% 
% for k = 1:35
%     
%     % update p and q
%     p = p.*mus/k;
%     q = q + p;
%     
%     % mark elements that just finished 
%     youCanStop = (u <= q);                      % all finished element
%     smpls(youCanStop & ~youCanStopPrev) = k;    % just finished elements
%     if all(youCanStop), break; end
%     youCanStopPrev = youCanStop;
%     
% end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getPoisCumProbLoopB(mus,u,q,p)
% not obvious to me why this version is faster, but it is


% initialize
iNotFinished = find(u > q);
smpls = zeros(size(mus));
k = 0;


p = p(iNotFinished);
q = q(iNotFinished);
mus = mus(iNotFinished);
smpls(iNotFinished) = smpls(iNotFinished) + 1;

% loop
while ~isempty(iNotFinished)
    
    k=k+1;
    if k > 35
        fprintf('warning: k > 35!!! -- jgm\n');
        smpls = getSamplesForSmallMu(mus);
    end

    % update p and q
    p = p.*mus/k;
    q = q + p;
    
    
    % update indices
    STILLNOTFINISHED = (u(iNotFinished) > q);
    iNotFinished = iNotFinished(STILLNOTFINISHED);
    
    p = p(STILLNOTFINISHED);
    q = q(STILLNOTFINISHED);
    mus = mus(STILLNOTFINISHED);
    smpls(iNotFinished) = smpls(iNotFinished) + 1;
    
end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getPoisCumProbLoopA(mus,u,q,p)

% initialize
ISFINISHED = (u <= q);
smpls = zeros(size(mus));
k = 0;

% loop
while ~all(ISFINISHED) % sum(iFinished) < length(smpls)
    
    k=k+1;
    if k > 35
        smpls = getSamplesForSmallMu(mus);
        % fprintf('warning: k > 35!!! -- jgm\n'); 
    end
    
    % update p and q
    p(~ISFINISHED) = p(~ISFINISHED).*mus(~ISFINISHED)/k;
    q(~ISFINISHED) = q(~ISFINISHED) + p(~ISFINISHED);
    
    % update indices
    ISFINISHEDold = ISFINISHED;
    ISFINISHED = (u <= q);
    iJustFinished = ISFINISHED&~ISFINISHEDold;
    
    smpls(iJustFinished) = k;
end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getPoisCumProbRecurse(mus,u,q,p,k)
% at least I think that's what it's doing
%%%% maybe try to rewrite according to new conventions.....

% are we finished?
iNotFinished = u > q;
smpls(~iNotFinished) = k;

if any(iNotFinished)
    k=k+1;
    if k > 35, fprintf('warning: k > 35!!! -- jgm\n'); end
    p = p(iNotFinished).*mus(iNotFinished)/k;
    q = q(iNotFinished) + p;
    smpls(iNotFinished) = getPoisCumProbRecurse(...
        mus(iNotFinished),u(iNotFinished),q,p,k);
end

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getSamplesForBigMu(mus)

% draw normal samples based on them
s = sqrt(mus);
g = mus + s.*randn(size(mus));
% g = mus - s*2;

% just for the positive samples:
iPosNormRnds = 0.0 <= g;

if any(iPosNormRnds)
    smpls(iPosNormRnds) = getSamplesForPosNormRnds(mus(iPosNormRnds),...
        floor(g(iPosNormRnds)),s(iPosNormRnds));
end
if ~all(iPosNormRnds)
    smpls(~iPosNormRnds) = getSamplesViaExpoSamples(...
        mus(~iPosNormRnds),s(~iPosNormRnds));
end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getSamplesForPosNormRnds(mus,smpls,s)

% immediate acceptance if large enough
L = floor(mus - 1.1484);
iDontAccept = (L > smpls);

if any(iDontAccept)
    smpls(iDontAccept) = getSamplesForMediateAcceptance(...
        mus(iDontAccept),smpls(iDontAccept),s(iDontAccept));
end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getSamplesForMediateAcceptance(mus,smpls,s)

% squeeze acceptance
difmuk = mus - smpls;
u = rand(size(mus));
% u = 0.3;
d = 6.0*mus.*mus;
iDontAccept = (difmuk.*difmuk.*difmuk > d.*u);

% but if not, getSamplesViaPxPyAcceptance, with "kflag" = 0 (empty arg)
if any(iDontAccept)
    smpls(iDontAccept) = getSamplesViaPxPyAcceptance(mus(iDontAccept),...
        smpls(iDontAccept),u(iDontAccept),s(iDontAccept),...
        difmuk(iDontAccept),[]);
end


end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getSamplesViaPxPyAcceptance(mus,smpls,u,s,difmuk,e)


omega = 0.3989423./s;
b1 = 0.04166667./mus;
b2 = 0.3*b1.*b1;
c3 = 0.1428571*b1.*b2;
c2 = b2 - 15.0*c3;
c1 = b1 - 6.0*b2 + 45.0*c3;
c0 = 1.0 - b1 + 3.0*b2 - 15.0*c3;
c = 0.1069./mus;

% get px and py, differently for smpls above and below 10
iSmallSmpls = (smpls < 10);
if any(iSmallSmpls)
    [px(iSmallSmpls,1),py(iSmallSmpls,1)] = getPxPyForSmallSamples(...
        mus(iSmallSmpls),smpls(iSmallSmpls));
end
if ~all(iSmallSmpls)
    [px(~iSmallSmpls,1),py(~iSmallSmpls,1)] = getPxPyForLargeSamples(...
        smpls(~iSmallSmpls),difmuk(~iSmallSmpls));
end


% get some other useful figures
x = (0.5 - difmuk)./s;
xx = x.*x;
fx = -0.5*xx;
fy = omega.*(((c3.*xx + c2).*xx + c1).*xx + c0);


% finish if some criterion is satisfied
if isempty(e) % kflag <=0 in the original

    iNotCrit = (fy - u.*fy > py.*exp(px - fx));
    if any(iNotCrit)
        smpls(iNotCrit) = getSamplesViaExpoSamples(mus(iNotCrit),s(iNotCrit));
    end

else
    
    iNotCrit = (c.*abs(u) > py.*exp(px + e) - fy.*exp(fx + e));
    if any(iNotCrit)
        smpls(iNotCrit) = getSamplesViaExpoSamples(mus(iNotCrit),s(iNotCrit));
    end

end

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function [px,py] = getPxPyForSmallSamples(mus,smpls)


fact = [1.0;1.0;2.0;6.0;24.0;120.0;720.0;5040.0;40320.0;362880.0];

px = -mus;
py = mus.^smpls./fact(smpls+1);

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function [px,py] = getPxPyForLargeSamples(smpls,difmuk)


del = 0.8333333e-01./smpls;
del = del - 4.8.*del.*del.*del;
v = difmuk./smpls;

iBigAbsv = (0.25 < abs(v));
if any(iBigAbsv)
    px(iBigAbsv) = getPxForBigAbsv(...
        smpls(iBigAbsv),v(iBigAbsv),difmuk(iBigAbsv),del(iBigAbsv));
end
if ~all(iBigAbsv)
    px(~iBigAbsv) = getPxForSmallAbsv(...
        smpls(~iBigAbsv),v(~iBigAbsv),del(~iBigAbsv));
end

py = 0.3989423./sqrt(smpls);

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function px = getPxForBigAbsv(smpls,v,difmuk,del)


px = smpls.*log(1.0 + v) - difmuk - del;

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function px = getPxForSmallAbsv(smpls,v,del)


a0 = -0.5;
a1 =  0.3333333;
a2 = -0.2500068;
a3 =  0.2000118;
a4 = -0.1661269;
a5 =  0.1421878;
a6 = -0.1384794;
a7 =  0.1250060;

px = smpls.*v.*v.*(((((((a7.*v+a6).*v+a5).*v+a4).*v+a3).*v+a2).*v+a1).*v+a0) - del;

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getSamplesViaExpoSamples(mus,s)


e = exprnd(ones(size(mus)));
u = 2.0*rand(size(mus)) - 1.0;
t = 1.8 + e.*sign(u);

itTooSmall = (t <= -0.6744);
if any(itTooSmall)
    smpls(itTooSmall) = getSamplesViaExpoSamples(mus(itTooSmall),...
        s(itTooSmall));
end
if ~all(itTooSmall)
    
    smpls(~itTooSmall) = getNewSamplesViaEtc(mus(~itTooSmall),...
        u(~itTooSmall),s(~itTooSmall),t(~itTooSmall),e(~itTooSmall));

end

end
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function smpls = getNewSamplesViaEtc(mus,u,s,t,e)

smpls = floor(mus + s.*t);
difmuk = mus - smpls;

smpls = getSamplesViaPxPyAcceptance(mus,smpls,u,s,difmuk,e);

end
%-------------------------------------------------------------------------%



%-------------------------------------------------------------------------%
%-------------------------------------------------------------------------%
%%% Note: you can test the Poisson-ness of these samples with, e.g., a chi-
%%% squared goodness-of-fit test.  The following code compares ignpoi to
%%% poissrnd; they both reject (as expected) 5% of distributions.  Note
%%% that ignpoi is faster.
%
% clc;
% 
% M = 1000; 
% N = 1800;
% lambda = 4;
% 
% 
% 
% htotal = 0;
% tic;
% for sim=1:M
%     X = poissrnd(lambda*ones(N,1));
%     [H,P,STATS] = chi2gof(X,'cdf',@(z)poisscdf(z,lambda));
%     htotal = htotal + H;
% end
% toc;
% htotal/M
% 
% 
% htotal = 0;
% tic;
% for sim=1:M
%     X = ignpoi(lambda*ones(N,1));
%     [H,P,STATS] = chi2gof(X,'cdf',@(z)poisscdf(z,lambda));
%     htotal = htotal + H;
% end
% toc;
% htotal/M
%-------------------------------------------------------------------------%