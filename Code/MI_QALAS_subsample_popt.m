
function [popt,fval,exitflag,output,lambda,grad,hessian] = MI_QALAS_subsample_popt...
    (pdarg,tisinput,materialID,synthdataT1,synthdataT2,synthdataM0,B1inhomflag,pspacelabels,subsmpllabels,acqparam,pinit,pAeq,pbeq,pmin,pmax,findiffrelstep,tolx,tolfun,maxiter,filenametmp)

%% Optimization Space Acquisition Parameters
% optcase=1;
% geometrycase=1.5;
% B1inhomflag=1;
% pspacelabels={'flipAngle','TD(1)','TD(2)','TD(3)','TD(4)'};
% pinit=[4,1,1,1,1];
% pmin=[0,0,0,0,0];
% pmax=[180,2,2,2,2];
% findiffrelstep=1.e-8;
% tolx=1.e-8;
% tolfun=1.e-8;
% maxiter=500;

% %% Tissue Properties
% % M0/T1/T2 Variance Flags
% M0varflag = 1;
% T1varflag = 1;
% T2varflag = 1;
% % CSFvarflag
% 
% % GM/WM/CSF M0/T1/T2 Values
% %              GM    WM   CSF  Tumor
% T1mean = [1200,  900, 4000, 1200]./1000; % s
% if T1varflag~=0
%     T1stdd = [ 100,  100,  200,  150]./1000; % s
% else
%     T1stdd = [   0,    0,    0,    0];
% end
% T2mean = [ 100,   80, 1000,  110]./1000; % s
% if T2varflag~=0
%     T2stdd = [   5,    4,   50,   10]./1000; % s
% else
%     T2stdd = [   0,    0,    0,    0];
% end
% M0mean = [ 0.9,  0.9,  1.0,  0.9];       % relative intensity
% if M0varflag~=0
%     M0stdd = [ .05,  .05,  .05,   .1];       % relative intensity
% else
%     M0stdd = [   0,    0,    0,    0];
% end
% 
% tisinput=[M0mean;M0stdd;T1mean;T1stdd;T2mean;T2stdd];

% %% Default Acquisition Parameters
% flipAngle = 4;           % deg
% TR = 0.005;              % s
% TE_T2prep = 0.100;       % s
% Tacq = 0.500;            % s
% TDpT2 = 0.03;            % s
% TDinv = 0;               % s
% nacq = 5;
% TD = [1,1,1,1];          % s
% 
% acqparam=[flipAngle,TR,TE_T2prep,Tacq,TDpT2,TDinv,nacq,TD];

%% Input files
% labelfilename = '/rsrch1/ip/dmitchell2/github/SyntheticMR/Code/ICBM_grey_white_csf.nii.gz'; % population tissue segmentation

% %% Loading tissue types
% % disp('loading tissue types');
% switch geometrycase
%     case 1
%         materialID = int32(1);
%         geometryflag=1;
%     case 1.5
%         materialID = int32([1,2,3]);
%         geometryflag=1;
%     case 1.75
%         system(sprintf('/opt/apps/itksnap/c3d-1.1.0-Linux-x86_64/bin/c3d %s -dilate 3 8x8x8vox -interpolation NearestNeighbor -resample 36x43x36 -o resampleimg.nii.gz',labelfilename));
%         tissuelabel = load_untouch_nii('resampleimg.nii.gz');
%         system('rm resampleimg.nii.gz');
%         materialID=int32(tissuelabel.img(:,:,ceil(size(tissuelabel.img,3)/2)));
%         geometryflag=0;
%     case 2
%         tissuelabel = load_untouch_nii(labelfilename);
%         materialID=int32(tissuelabel.img(15:165,20:200,92));
%         geometryflag=0;
%     case 2.5
%         system(sprintf('/opt/apps/itksnap/c3d-1.1.0-Linux-x86_64/bin/c3d %s -dilate 3 8x8x8vox -interpolation NearestNeighbor -resample 36x43x36 -o resampleimg.nii.gz',labelfilename));
%         tissuelabel = load_untouch_nii('resampleimg.nii.gz');
%         system('rm resampleimg.nii.gz');
%         materialID = int32(tissuelabel.img);
%         geometryflag=0;
%     case 0
%         system(sprintf('/opt/apps/itksnap/c3d-1.1.0-Linux-x86_64/bin/c3d %s -dilate 3 8x8x8vox -interpolation NearestNeighbor -resample 36x43x36 -o resampleimg.nii.gz',labelfilename));
%         tissuelabel = load_untouch_nii('resampleimg.nii.gz');
%         system('rm resampleimg.nii.gz');
%         materialID = int32(tissuelabel.img);
%         geometryflag=0;
%     otherwise
%         tissuelabel = load_untouch_nii(labelfilename);
%         materialID = int32(tissuelabel.img);
%         geometryflag=0;
% end

%% Optimization
tic;
[popt,fval,exitflag,output,lambda,grad,hessian]=fmincon(@(x) MI_QALAS_objfun_nd_subsample(x,pspacelabels,subsmpllabels,tisinput,synthdataT1,synthdataT2,synthdataM0,acqparam,materialID,pdarg,B1inhomflag,filenametmp),...
    pinit,pAeq,pbeq,[],[],pmin,pmax,[],...
    optimset('FinDiffRelStep',findiffrelstep,'TolX',tolx,'TolFun',tolfun,'MaxIter',maxiter,'Display','iter-detailed','OutputFcn',@outfun));
toc;

% syntheticevalvar_np_subsample(pinit,pspacelabels,subsmpllabels,tisinput,acqparam,materialID,optcase,geometryflag,B1inhomflag)

end