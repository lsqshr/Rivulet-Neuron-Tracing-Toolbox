function [covermask, centremask] = binarysphere3d(sz, pts, radius)
% Generate a mask with 3d spheres to cover a list of 2d points 
% sz: the size of the original image
% pts: a list of 3d point coordinates < N * D>
% radius: a list of radius corresponding to the pts

	%Initialize the 3d binary matrix with zeros 
	covermask = logical(zeros(sz));
	centremask = logical(zeros(sz));
	for i = 1 : size(pts, 1) 
		neighbours = neighbourpoints3d(pts(i, 1), pts(i, 2), pts(i, 3), radius(i));
		neighbours(:, 1) = constrain(neighbours(:, 1), 1, sz(1));
		neighbours(:, 2) = constrain(neighbours(:, 2), 1, sz(2));
		neighbours(:, 3) = constrain(neighbours(:, 3), 1, sz(3));
		ind = sub2ind(sz, int16(neighbours(:, 1)), int16(neighbours(:, 2)), int16(neighbours(:, 3)));
		covermask(ind) = 1;
		centremask(constrain(ceil(pts(i, 1)), 1, sz(1)),...
		           constrain(ceil(pts(i, 2)), 1, sz(2)),... 
		           constrain(ceil(pts(i, 3)), 1, sz(3)))=1;
	end

end
