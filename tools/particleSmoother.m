function [Ws,XfXp] = particleSmoother(Xtu,Wf,qLDSparams,USELOGS)
% particleSmoother  Particle smoother for linear-Gaussian dynamical systems
%
% USAGE:
%   [Ws,XfXp] = particleSmoother(Xfiltered,qLDSparams,USELOGS)
%
% Like RTSsmoother.m, particleSmoother must be given a filtered trajectory;
% but in this case it consists of many sample trajectories (particles) and
% their probabilties, Xtu and Wf--probably generated by particleSmoother.m.
% They should have sizes (Nstates x Nparticles x T) and (Nparticles x T).
%
% In addition, the parameters of the LDS must be provided in a structure
% called qLDSparams, with fields muX, SigmaX, and A. (In future versions,
% this structure may be replaced by a function that returns probability 
% densities.)
%
% Finally, the user tells this function whether or not to USELOGS in the
% probability computations--which will generally be slower but more 
% accurate, because it prevents round-off errors.
%
% Then particleSmoother returns the probabilities, Ws, of each sample in
% Xtu at each time step; and one of the expected sufficient statistics,
% XfXp = E[X_{t+1}*X_t'|y_0,...,y_T].  
%
% NB that XfXp is the SUM, not the mean, of XfXp across all time!!
% 
% NB: This smoother assumes linear-Gaussian dynamics!  Generalizing it to
% other dynamics may be complicated---see e.g. "A Tutorial on Particle
% Filtering and Smoothing: Fifteen years later," Doucet and Johansen 2008.


%-------------------------------------------------------------------------%
% Revised: 08/31/16
%   -whitened and transformed means (Xt -> A*Xt) *outside* of mvnpdf, since
%   by that point the data have been repmatted (so this should be faster).
%   Now you calculate the probability under the normal distribution with yr
%   own code (since you need to adjust by the normalizer based on the
%   pre-whitened covariance matrix)
% Revised: 08/30/16
%   -re-wrote in terms of sampling weights rather than samples trajectories
%   (it's more efficient to just compute and store the former, because the
%   latter are (a) bigger and (b) just permuted versions of the set of
%   samples you already have in Xtu)
% Created: 08/28/16
%   by JGM
%-------------------------------------------------------------------------%

% check arguments
if nargin < 4
    USELOGS = 0;
    if nargin < 3
        error('particleSmoother.m needs more arguments -- jgm');
    end
end
SLOWPROC = 1;

% Ns
[Nstates,Nparticles,T] = size(Xtu);


% for speed, prepare by whitening data
SigmaOneHalf = chol(qLDSparams.SigmaX)';
if isa(Wf,'gpuArray'), SigmaOneHalf = gpuArray(SigmaOneHalf); end;
V = reshape(SigmaOneHalf\Xtu(:,:),size(Xtu));
MU = reshape((SigmaOneHalf\qLDSparams.A)*Xtu(:,:) +...
    SigmaOneHalf\qLDSparams.muX,size(Xtu));
logZ = size(SigmaOneHalf,1)*log(2*pi)/2 + sum(log(diag(SigmaOneHalf)));

% malloc/init
Ws = zeros([Nparticles,T],'like',Wf);
Ws(:,end) = Wf(:,end);
XfXp = 0;


% smooth backwards in time
if SLOWPROC, tic; fprintf('\n'); end
for t = (T-1):-1:1
    
    % Get P := p(x_{t+1}|x_t), evaluated at all combinations of
    %   x_{t+1} ~ p(x_{t+1}|y_0,...,y_t) and
    %       x_t ~ p(x_t|y_0,...,y_t)
    % To evaluate p(x_{t+1}|x_t), we need A*x_t.
    % reshape: Nstates x Nparticles (X_{t+1}) x Nparticles (X_t)
    Vnext = repmat(V(:,:,t+1),[1,1,Nparticles]);
    MUnow = repmat(reshape(MU(:,:,t),[Nstates,1,Nparticles]),[1,Nparticles,1]);
    
    Xnext = repmat(Xtu(:,:,t+1),[1,1,Nparticles]);
    Xnow = repmat(reshape(Xtu(:,:,t),[Nstates,1,Nparticles]),[1,Nparticles,1]);
    
    if USELOGS
        
        % L := log p(x_{t+1}|x_t), where X_s ~ p(x_s|y_0,...,y_{s-1})
        L = squeeze(-sum((Vnext - MUnow).^2)/2) - logZ ;
        
        % intermediate term: 
        % p(x_{t+1}^k|x_t^j)*Ws_{t+1}^j/sum_m p(x_{t+1}^k|x_t^m)*Wf_t^m
        R = (L - logprobs2logsumprobs(L' + Wf(:,t))') + Ws(:,t+1);
        
        % p(x_t|y_0,...y_T) ~= \sum_n Ws_n delta{x_t - Xtu(:,t)_n}
        Ws(:,t) = Wf(:,t)' + logprobs2logsumprobs(R);
        
        % p(x_t,x_{t+1}|y_0,...y_T) ~= \sum_n 
        %   Wx_n delta{x_t - Xtu(:,t)_n}delta{x_{t+1} - Xtu(:,t+1)_n}
        Wxx = Wf(:,t)' + R;
        
        % E[X_t*X_{t+1}'|y_0,...,y_T],  weighted sum of outer products
        XfXp = XfXp + (Xnext(:,:).*exp(Wxx(:)'))*Xnow(:,:)';

    else
        
        % P := p(x_{t+1}|x_t), where X_s ~ p(x_s|y_0,...,y_{s-1})
        P = exp(-squeeze(sum((Vnext - MUnow).^2))/2 - logZ);
        
        % intermediate term: 
        % p(x_{t+1}^k|x_t^j)*Ws_{t+1}^j/sum_m p(x_{t+1}^k|x_t^m)*Wf_t^m
        R = (P./(P*Wf(:,t))).*Ws(:,t+1);
        
        % p(x_t|y_0,...y_T) ~= \sum_n Ws_n delta{x_t - Xtu(:,t)_n}
        Ws(:,t) = Wf(:,t)'.*sum(R);
        
        % p(x_t,x_{t+1}|y_0,...y_T) ~= \sum_n 
        %   Wf_n delta{x_t - Xtu(:,t)_n}delta{x_{t+1} - Xtu(:,t+1)_n}
        Wxx = Wf(:,t)'.*R;
        
        % E[X_t*X_{t+1}'|y_0,...,y_T],  weighted sum of outer products
        XfXp = XfXp + (Xnext(:,:).*Wxx(:)')*Xnow(:,:)';
           
    end
    if SLOWPROC, fprintf('.'); end
end
if SLOWPROC, toc; fprintf('\n'); else, fprintf('.'); end


end

