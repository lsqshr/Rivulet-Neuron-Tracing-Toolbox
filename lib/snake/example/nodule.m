clear all; close all; clc;

% Read image
im=imread('mama07ORI.bmp');

% The following two lines basically make the edge of image more obvious
gI = snakegborder(im, 5, 1000);
gI = double(gI) / 255;
gI = rgb2gray(gI);

% The parameter intialization smoothing control the smoothness which is basically the iteration number of SIIS ISSI
% ballon control the ballon force parameter
smoothing = 1;
threshold = 0.3;
ballon = 1;

% The initialization of snake using geodesic active contour algorithm
MorphGAC = snakeinitialise(gI, smoothing, threshold, ballon);

% Basically it creates a logical disk with true elements inside and false elements outside
shape = size(im);
scalerow = 0.75;
center = [100, 126];
sqradius = 20;
u = circlelevelset(shape, center, sqradius, scalerow);

MorphGAC = snakelevelset(MorphGAC, u);

% The following kernel is used for the SI and IS operation 
global P2
P2{1} = eye(3);
P2kernel = ones(3);
P2kernel(:,1) = 0;
P2kernel(:,3) = 0;
P2{2} = P2kernel;
P2{3} = flipud(P2{1});
P2{4} = P2kernel';

% Each move the snake will evolue one step 
figure
for i = 1 : 200 
	MorphGAC = snakestep(MorphGAC);
	imshow(MorphGAC.u);
	drawnow;
end