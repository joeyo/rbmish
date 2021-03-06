function [XhatStatic,RsqStatic,XhatDynamic,RsqDynamic,Bv,LDSparams] =...
    filterDecoder(Vtrain,Xtrain,Vtest,Xtest,Ntraj,SStot)
% filterDecoder    Decode variables from a latent-state filter
% 
% USAGE:
%   [XhatStatic,RsqStatic,XhatDynamic,RsqDynamic,Nv,LDSparams] =...
%       filterDecoder(Vtrain,Xtrain,Vtest,Xtest,Ntraj,SStot);
% 
% Suppose you fit to observed dynamical data a latent-variable model--say, 
% an LTI system, or an rEFH--but you also have in hand some other set of 
% latent variables, X, that you'd like to "decode." You could simply decode
% X from the variable V of the latent-variable model (its hidden state or
% perhaps even more).  But you could furthermore use those decoded
% estimates as themselves observations from an LTI system with X on the
% backbone--and therefore apply a Kalman filter.  This function acquires
% both of these decoders, static (Bv) and dynamic (LDSparams), on training 
% pairs Vtrain and Xtrain, and returns estimates (XhatStatic,XhatDynamic) 
% and coefficients of determination (RsqStatic,RsqDynamic) for the testing
% pairs, Vtest,Xtest. 
%
% The number of "trajectories" (Ntraj) which compose the test data, and
% their total sum of squares (SStot), must also be passed as inputs.

%-------------------------------------------------------------------------%
% Revised: 03/13/17
%   -cleaned up, generalized so that it applies to LDS models as well as
%   rEFHs.
%   -renamed: linearREFHDecoder ->
% Revised: 03/11/17
%   -finally settled on a regularization/decoding scheme
% Revised: 01/11/17
%   -part of the Grand Revision
% Revised: 09/27/16
%   -added KF decoder based on observed LDS model
%   -functionized, rationalized, cleaned up
% Created: ??/??/16
%   by JGM
%-------------------------------------------------------------------------%

% train decoders, apply static, apply dynamic
[Bv,LDSparams] = getREFHDecoders(Vtrain,Xtrain,Ntraj);
[XhatStatic,RsqStatic] = testStaticDecoders(Vtest,Xtest,Bv,SStot);
[XhatDynamic,RsqDynamic] = testDynamicDecoders(XhatStatic,Xtest,LDSparams,SStot);

end
%-------------------------------------------------------------------------%
%-------------------------------------------------------------------------%


%-------------------------------------------------------------------------%
function [Bvx,LDSparamsObs] = getREFHDecoders(V,X,Ntraj)

% static decoder
[Nsamples,Nv] = size(V);
[Bvx,~,~,Xhat] = linregress(V,X,'none',(Nv/Nsamples)^(10/3));

% dynamic decoder
LDSparamsObs = learnfullyobservedLDS(shortdata(Ntraj,3,Xhat),...
    shortdata(Ntraj,3,X));
LDSparamsObs.mu0 = mean(X)';                    % use *all* data to get 
LDSparamsObs.Info0 = inv(cov(X));               %   initial state

end
%-------------------------------------------------------------------------%

%-------------------------------------------------------------------------%
function [XhatStatic,RsqStatic] = testStaticDecoders(V,X,Bv,SStot)

XhatStatic = V*Bv;
RsqStatic  = 1 - sum((XhatStatic - X).^2)./SStot;
fprintf('R^2 for static map, [composite] -> X:\n');
rprintr(RsqStatic); fprintf('\n');

end
%-------------------------------------------------------------------------%

%-------------------------------------------------------------------------%
function [XhatDynamic,RsqDynamic] = testDynamicDecoders(Xhat,Xtest,...
    LDSparams,SStot)

% test Kalman filter on LDS
LDSparams.T = size(Xhat,1);
KFdstrbs = KalmanFilter(LDSparams,Xhat');
XhatDynamic = KFdstrbs.XHATMU';
%%% This would be cheating, of course, but it could be interesting:
% RTSSdstrbs = RTSsmoother(LDSparamsObs,KFdstrbsTrainObs);
% XhatZhat = RTSSdstrbs.XHAT';
%%%

RsqDynamic = 1 - sum((XhatDynamic - Xtest).^2)./SStot;
fprintf('R^2 for dynamic (KF) map, [decoded X] -> X:\n');
rprintr(RsqDynamic); fprintf('\n');

end
%-------------------------------------------------------------------------%

%-------------------------------------------------------------------------%
function rprintr(Rsqs)

arrayfun(@(ii)(fprintf('% 0.2f ',Rsqs(ii))),1:length(Rsqs));

end
%-------------------------------------------------------------------------%