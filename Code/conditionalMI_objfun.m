
% MI-based optimization of parameter space using fminsearch
% MI calculated by Gauss-Hermite quadrature

function [MIobjfun]=conditionalMI_objfun(pspace,pspacelabels,subsmpllabels,tisinput,acqparam,materialID)

%% Assign Acquisition Parameters
% Default Parameters
flipAngle=acqparam(1);
TR=acqparam(2);
TE_T2prep=acqparam(3);
Tacq=acqparam(4);
TDpT2=acqparam(5);
TDinv=acqparam(6);
nacq=acqparam(7);
TD=acqparam(8:6+nacq);

% Optimization Parameters
for iii=1:length(pspacelabels)
    eval(sprintf('%s=pspace(iii);',pspacelabels{iii}));
end

% Subsampling Parameters
for iii=length(pspacelabels)+1:length(subsmpllabels)
    eval(sprintf('%s=pspace(iii);',subsmpllabels{iii}));
end

%% Generate Quadrature Points for MI Calculation
NumQP=5;
[~,xn,~,~,wn]=GaussHermiteNDGauss(NumQP,[tisinput(3,1:3),tisinput(5,1:3)],[tisinput(4,1:3),tisinput(6,1:3)]);
lqp=length(xn{1}(:));
parfor qp=1:lqp
    %     disp(sprintf('Model eval: %d of %d',qp,lqp))
    dt=[0,TE_T2prep,Tacq,TDpT2,0,TDinv,Tacq,TD(1),Tacq,TD(2),Tacq,TD(3),Tacq,TD(4)];
    [~,Mmodel_GM(:,qp)]=qalas1p(tisinput(1,1),tisinput(1,1),xn{1}(qp),xn{4}(qp),TR,TE_T2prep,flipAngle,nacq,dt);
    [~,Mmodel_WM(:,qp)]=qalas1p(tisinput(1,2),tisinput(1,2),xn{2}(qp),xn{5}(qp),TR,TE_T2prep,flipAngle,nacq,dt);
    [~,Mmodel_CSF(:,qp)]=qalas1p(tisinput(1,3),tisinput(1,3),xn{3}(qp),xn{6}(qp),TR,TE_T2prep,flipAngle,nacq,dt);
end

%% Gauss-Hermite Quadrature MI Approximation
% N-D k-space, no averaging
nd=ndims(materialID);
evalstr=sprintf('kspace(jjj%s)=fftshift(fftn(squeeze(imspace(jjj%s))));',repmat(',:',[1,nd]),repmat(',:',[1,nd]));
imspace=0; Ezr=0; Ezi=0; Sigrr=0; Sigii=0; Sigri=0;
materialIDtemp=repmat(permute(materialID,[nd+1,1:nd]),[nacq,ones([1,nd])]);
for iii=1:length(wn(:))
    imspace=zeros(size(materialIDtemp))+(materialIDtemp==1).*Mmodel_GM(:,iii)+(materialIDtemp==2).*Mmodel_WM(:,iii)+(materialIDtemp==3).*Mmodel_CSF(:,iii);
    %         if optcase~=0
    for jjj=1:size(imspace,1)
        eval(evalstr);
        %                 kspace(jjj,:,:)=fftshift(fftn(squeeze(imspace(jjj,:,:))));
    end
    ksr=real(kspace);
    ksi=imag(kspace);
    
    Ezr=Ezr+ksr*wn(iii);
    Ezi=Ezi+ksi*wn(iii);
    Sigrr=Sigrr+ksr.^2*wn(iii);
    Sigii=Sigii+ksi.^2*wn(iii);
    Sigri=Sigri+ksr.*ksi*wn(iii);
end
% end

N=length(xn);
% std of patient csf = 9.8360; max signal in patient brain = 500;
% max approx signal in synthdata = 0.0584
% std of noise in patient raw data = 17.8574; max signal approx 3000;
signu=3.4762E-4;
B1inhomflag=0;
if B1inhomflag==1
    signu=signu*(1+flipAngle/1.2);
end
detSigz=(pi^(-N/2)*signu^2 + Sigrr - Ezr.^2).*(pi^(-N/2)*signu^2 + Sigii - Ezi.^2) - (Sigri - Ezr.*Ezi).^2;
Hz=0.5.*log((2*pi*2.7183)^2.*detSigz);
Hzmu=0.5.*log((2*pi*2.7183)^2.*signu.^4);
MI=Hz-Hzmu;

% szmi=size(MI);
MIobjfun=-sum(MI(:));
MIobjfun
end

%% Reconstruct to Compute Variances
reconflag=1;
if reconflag~=0

    %% Create synthetic QALAS measurements
    dt=[0,TE_T2prep,Tacq,TDpT2,0,TDinv,Tacq,TD(1),Tacq,TD(2),Tacq,TD(3),Tacq,TD(4)];
    [~,Mmeas]=qalas(synthdataM0,synthdataM0,synthdataT1,synthdataT2,TR,TE_T2prep,flipAngle,nacq,dt);
    stdmapmeas=signu*noise;
    Mmeas=Mmeas+stdmapmeas;

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % THE FOLLOWING SECTION ONLY WORKS FOR 2D!
    % FIX IT FOR N-D!!

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %% Subsample synthetic measurements
    Mmeassub=Mmeas;
if pdarg(3)~=-1
        Mmeassub(isnan(Mmeassub))=0;
        kmeas=bart('fft 3',Mmeassub);
        subsample=squeeze(subsmplmask(1,:,:));
        subsample=repmat(subsample,[1,1,size(kmeas,3),size(kmeas,4)]);
%         Mmeassub=bart('pics',kmeas.*subsample,ones(size(kmeas)));
        Mmeassub=bart('fft -i 3',kmeas.*subsample)*size(kmeas,4)/numel(kmeas);
        Mmeassub=double(real(Mmeassub));
        Mmeassub(repmat(materialID,[1,1,size(Mmeassub,3),size(Mmeassub,4)])==0)=nan;
end
%     end

    %% Reconstruct synthetic QALAS measurements
    % Optimization solution for M0 and T1 prediction
%     xinit=[mean(tisinput(1,1:3)),mean(tisinput(3,1:3))];%,mean(tisinput(5,1:3))];
    smeas=size(Mmeassub);
    Mmeasvec=reshape(Mmeassub,[prod(smeas(1:3)),smeas(4:end)]);
    mmvsize=size(Mmeasvec,1);
    parfor iii=1:size(Mmeasvec,1)
        if sum(isnan(squeeze(Mmeasvec(iii,:))))>0
            M0predvec(iii)=0;%nan;
            T1predvec(iii)=0;%nan;
            T2predvec(iii)=0;%nan;
        else
            [M0predvec(iii),T1predvec(iii),T2predvec(iii)]=qalasrecon(squeeze(Mmeasvec(iii,:)),TR,TE_T2prep,flipAngle,nacq,dt);
        end
        %         fprintf('Element: %d of %d\n',iii,mmvsize)
    end
    M0pred(:,:,:)=reshape(M0predvec,smeas(1:3));
    T1pred(:,:,:)=reshape(T1predvec,smeas(1:3));
    T2pred(:,:,:)=reshape(T2predvec,smeas(1:3));

    M0p1set=M0pred(:).*(materialID(:)==1); M0p1set=M0p1set(M0p1set~=0);
    M0p2set=M0pred(:).*(materialID(:)==2); M0p2set=M0p2set(M0p2set~=0);
    M0p3set=M0pred(:).*(materialID(:)==3); M0p3set=M0p3set(M0p3set~=0);
    T1p1set=T1pred(:).*(materialID(:)==1); T1p1set=T1p1set(T1p1set~=0);
    T1p2set=T1pred(:).*(materialID(:)==2); T1p2set=T1p2set(T1p2set~=0);
    T1p3set=T1pred(:).*(materialID(:)==3); T1p3set=T1p3set(T1p3set~=0);
    T2p1set=T2pred(:).*(materialID(:)==1); T2p1set=T2p1set(T2p1set~=0);
    T2p2set=T2pred(:).*(materialID(:)==2); T2p2set=T2p2set(T2p2set~=0);
    T2p3set=T2pred(:).*(materialID(:)==3); T2p3set=T2p3set(T2p3set~=0);

    M0varmeas=[quantile(M0p1set,0.975)-quantile(M0p1set,0.025)...
        quantile(M0p2set,0.975)-quantile(M0p2set,0.025)...
        quantile(M0p3set,0.975)-quantile(M0p3set,0.025)];
    T1varmeas=[quantile(T1p1set,0.975)-quantile(T1p1set,0.025)...
        quantile(T1p2set,0.975)-quantile(T1p2set,0.025)...
        quantile(T1p3set,0.975)-quantile(T1p3set,0.025)];
    T2varmeas=[quantile(T2p1set,0.975)-quantile(T2p1set,0.025)...
        quantile(T2p2set,0.975)-quantile(T2p2set,0.025)...
        quantile(T2p3set,0.975)-quantile(T2p3set,0.025)];
    varstats=[M0varmeas;T1varmeas;T2varmeas];

    meanstats=[mean(M0p1set),mean(M0p2set),mean(M0p3set);
        mean(T1p1set),mean(T1p2set),mean(T1p3set);
        mean(T2p1set),mean(T2p2set),mean(T2p3set)];

    medianstats=[median(M0p1set),median(M0p2set),median(M0p3set);
        median(T1p1set),median(T1p2set),median(T1p3set);
        median(T2p1set),median(T2p2set),median(T2p3set)];

    %% Save statistics
%     filename='/rsrch1/ip/dmitchell2/github/SyntheticMR/Code/MI_QALAS_subsample_poptrecons.mat';
    if exist(filename,'file')==2
        load(filename);
        pspacesave=cat(ndims(pspace)+1,pspacesave,pspace);
        MIsave=cat(ndims(MIobjfun)+1,MIsave,MIobjfun);
        varsave=cat(ndims(varstats)+1,varsave,varstats);
        meansave=cat(ndims(meanstats)+1,meansave,meanstats);
        mediansave=cat(ndims(medianstats)+1,mediansave,medianstats);
        M0save=cat(ndims(M0pred)+1,M0save,M0pred);
        T1save=cat(ndims(T1pred)+1,T1save,T1pred);
        T2save=cat(ndims(T2pred)+1,T2save,T2pred);
        Mmeassave=cat(ndims(Mmeas)+1,Mmeassave,Mmeas);
    else
        pspacesave=pspace;
        MIsave=MIobjfun;
        varsave=varstats;
        meansave=meanstats;
        mediansave=medianstats;
        M0save=M0pred;
        T1save=T1pred;
        T2save=T2pred;
        Mmeassave=Mmeas;
    end
    save(filename,'pspacesave','MIsave','varsave','meansave','mediansave','M0save','T1save','T2save','Mmeassave','-v7.3');
end

end