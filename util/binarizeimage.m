function [X, cropregion] = binarizeimage(varargin)
    % Segment the 3D v3draw uint image to binary image with a classifier or threshold
    % The segmentation will be enhanced with levelset
    % example:
    % binarizeimage('classifier', X, cl, delta_t, crop)
    % binarizeimage('threshold', X, threshold, delta_t, crop)
    % Use the trained classifier to enhance and binarize the foreground neuron from v3draw
    [pathstr, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(fullfile(pathstr, '..', 'scripts'));
    addpath(fullfile(pathstr, '..', 'lib', 'AOSLevelsetSegmentationToolboxM','AOSLevelsetSegmentationToolboxM'));
    addpath(fullfile(pathstr, '..', '..', '..', 'v3d', 'v3d_external', 'matlab_io_basicdatatype'));

    method = varargin{1};
    X = varargin{2};
    % [imgdir, ~, ~] = fileparts(path2img);
    delta_t = varargin{4};

    crop = false;
    if numel(varargin) >= 5
        crop = varargin{5};
    end

    levelset = false;
    if numel(varargin) >= 6
        levelset = varargin{6};
    end

    if strcmp(method, 'threshold')
        % X = load_v3d_raw_img_file(path2img);
        threshold = varargin{3};
        X = double(X > threshold); 
    else
        cl = varargin{3}
        
        if ~exist('tmp', 'dir')
          mkdir('tmp');
        end
        featextract(X, [], 1.2, fullfile('tmp', 'tmpfeat'));
        [X, ~, feats] = featcollect('tmp', []);
        pred = predict(cl, X);
        X = reshape(pred, size(feats.I));
        fprintf('Removing %s\n', 'tmp');
        rmdir('tmp', 's');
    end

    if levelset
        disp('Performing Linear Level-Set...')
        X = ac_linear_diffusion_AOS(X, delta_t);
    end

    if crop
        [X, cropregion] = imagecrop(X, 0.5);
        % disp('Image Size After Crop: ')
        % disp(size(X));
    else
        cropregion = zeros(3,2);
        cropregion(1,:) = [1, size(X, 1)];
        cropregion(2,:) = [1, size(X, 2)];
        cropregion(3,:) = [1, size(X, 3)];
    end

    X = X > 0.5;
end

