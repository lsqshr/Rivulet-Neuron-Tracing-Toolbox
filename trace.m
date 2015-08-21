function [tree, meanconf] = trace(varargin)
% Main tracing function
% imgpath: the path to the v3draw image
% Return: swc tree
% segmentmethod: 'threshold' / 'classification'
% threshold/cl: threshold for image segmentation when method is set threshold; / cl: .mat file containing the voxel classifier; can be [] when method is set 'threshold'
% plot(optional): plot the tracing progress or not; default false
% delta_t (optional): delta_t for level-set; default 1
% percentage(optional): finish until this proportion of binary image has been covered; default 0.95
% crop(optional): crop the image with threshold > 0; default true
% rewire: whether the result tree will be rewired

	I = varargin{1};

	plot = false;
    if numel(varargin) >= 2
		plot = varargin{2};
	end

	percentage = 0.95;
    if numel(varargin) >= 3
		percentage = double(varargin{3});
	end

	rewire = false;
	if numel(varargin) >= 4
		rewire = varargin{4};
    end
    
	gap = 10;
    if numel(varargin) >= 5
		gap = varargin{5};
	end

	ax = false;
    if numel(varargin) >= 6
		ax = varargin{6};
	end

    dumpbranch = false;
    if numel(varargin) >= 7
        dumpbranch = varargin{7};
    end

    connectrate = false;
    if numel(varargin) >= 8
        connectrate = varargin{8};
    end

	[pathstr, ~, ~] = fileparts(mfilename('fullpath'));
    addpath(fullfile(pathstr, 'util'));
    addpath(genpath(fullfile(pathstr, 'lib')));

    
    if plot
        h = waitbar(0.2, 'Preprocessing: Distance Tr...');
        set(h, 'windowstyle', 'modal');
        axes(ax);
    end
    disp('Distance transform');
    bdist = getBoundaryDistance(I, true);
    
    disp('Looking for the source point...')
    [SourcePoint, maxD] = maxDistancePoint(bdist, I, true);
    disp('Make the speed image...')
    SpeedImage=(bdist/maxD).^4;
	SpeedImage(SpeedImage==0) = 1e-10;
	if plot
        set(0, 'CurrentFigure', h);
		h = waitbar(0.5, h, 'Preprocessing: Marching...');
        set(h, 'windowstyle', 'modal');
        axes(ax);
	end	
	disp('marching...');
    oT = msfm(SpeedImage, SourcePoint, false, false);
    
    disp('Finish marching')

    

    % close all
    if plot
    	hold on 
    	% showbox(I, 0.5);
    end
    T = oT;
    tree = []; % swc tree
    prune = true;
	% Calculate gradient of DistanceMap
	disp('Calculating gradient...')
    grad = distgradient(T);
    if plot
        set(0, 'CurrentFigure', h);
		h = waitbar(0.8, h, 'Preprocessing: Calculate Distance Gradients...');
        set(h, 'windowstyle', 'modal');
        axes(ax);
    end
    S = {};
    B = zeros(size(T));
    i = 1;

    lconfidence = [];
    if plot
	    [x,y,z] = sphere;
	    surf(x + SourcePoint(2), y + SourcePoint(1), z + SourcePoint(3));
	end

    unconnectedBranches = {};

    while(true)

	    StartPoint = maxDistancePoint(T, I, true);
	    if plot
		    surf(x + StartPoint(2), y + StartPoint(1), z + StartPoint(3));
		end

	    if T(StartPoint(1), StartPoint(2), StartPoint(3)) == 0 || I(StartPoint(1), StartPoint(2), StartPoint(3)) == 0
	    	break;
	    end

	    [l, dump, merged] = shortestpath2(T, grad, I, StartPoint, SourcePoint, 1, 'rk4', gap);

	    % Get radius of each point from distance transform
	    radius = zeros(size(l, 1), 1);
	    for r = 1 : size(l, 1)
		    radius(r) = getradius(I, l(r, 1), l(r, 2), l(r, 3));
		end
	    radius(radius < 1) = 1;
	    % disp([size(l, 1), size(radius, 1)]);
		assert(size(l, 1) == size(radius, 1));

	    % Remove the traced path from the timemap
	    tB = binarysphere3d(size(T), l, radius);
	    tB(StartPoint(1), StartPoint(2), StartPoint(3)) = 3;
	    T(tB==1) = -1;

	    % Add l to the tree
	    if ~(dump && dumpbranch) 
		    [tree, newtree, conf, unconnected] = addbranch2tree(tree, l, merged, connectrate, radius, I, plot);
            if unconnected
                unconnectedBranches = {unconnectedBranches, newtree};
            end
            lconfidence = [lconfidence, conf];
		end

        B = B | tB;

        percent = sum(B(:) & I(:)) / sum(I(:));
%         fprintf('Percent: %.2f/%.2f\n', percent * 100, percentage * 100);
        if plot
%             disp(percent)
            set(0, 'CurrentFigure', h);
%             h = waitbar(percent, h, sprintf('Tracing %.2f%%', percent*100 / percentage));
            h = waitbar(percent, h);
            set(h, 'windowstyle', 'modal');
%             set(0, 'CurrentFigure', gcf);
            axes(ax);
        end
        if percent >= percentage
            if plot
                close(h)
            end
        	disp('Coverage reached end tracing...')
        	break;
        end

    end

    % % Shift the result tree back to the original space if crop was conducted
    % if crop
    %     tree(:, 3) = tree(:, 3) + cropregion(1, 1);
    %     tree(:, 4) = tree(:, 4) + cropregion(2, 1);
    %     tree(:, 5) = tree(:, 5) + cropregion(3, 1);
    % end

    % Double check the unconnected terminis
    for t = unconnectedBranches
        t1 = t(1, :);
        t2 = t(end, :);
        tid = t(:, 1);
        treeid = tree(:, 1);
        rest = tree(~ismember(treeid, tid), :);
        [d1, idx1] = pdist2(t1(3:5), rest(:, 3:5));

        if (d1 < (rest(idx1, 6) + 3) * connectrate || d1 < (t1(6) + 3) * connectrate)
            fprintf('Rewire (%f, %f, %f) to (%f, %f, %f)\n', t1(3:5), rest(idx1, 3:5));
            tree(treeid == t1(1), 7) = rest(idx1, 1); % Connect to the tree parent
            if plot
                plot3([t1(4); rest(idx1, 4)], [t1(3);rest(idx1, 3)], [t1(5);rest(idx1, 5)], 'r-.');
                drawnow
            end
        end

        [d2, idx2] = pdist2(t2(3:5), rest(:, 3:5));
        if (d2 < (rest(idx2, 6) + 3) * connectrate || d2 < (t1(6) + 3) * connectrate)
            fprintf('Rewire (%f, %f, %f) to (%f, %f, %f)\n', t2(3:5), rest(idx2, 3:5));
            tree(treeid == t2(1), 7) = rest(idx2, 1); % Connect to the tree parent
            if plot
                plot3([t2(4); rest(idx2, 4)], [t2(3);rest(idx2, 3)], [t2(5);rest(idx2, 5)], 'r-.');
                drawnow
            end
        end
    end

    % Deprecated for now
    if rewire
	    rewiredtree = rewiretree(tree, S, I, lconfidence, 0.7);
	    rewiredtree(:, 6) = 1;
	    save_v3d_swc_file(rewiredtree, [imgpath, '.rewired.swc']);
	    tree = rewiredtree;
	end
    meanconf = mean(lconfidence);

	if plot
		hold off
	end

end