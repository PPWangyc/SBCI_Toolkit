% MATLAB R2018a
%
% FUNCTION NAME:
%   parcellate_fc
%
% DESCRIPTION:
%   Convert continuous high-resolution FC to discrete atlas ROI level FC
%
% INPUT:
%   data - (matrix) A PxP matrix of continuous connectivity data   
%   sbci_parc - (struct) A struct with parcellation output from SBCI
%   sbci_map - (struct) A structure containing SBCI mapping information
%   varargin - Optional arguments:
%       roi_mask - (vector) A vector of label IDs for ROIs to remove
%
% OUTPUT:
%   result - (matrix) discrete, atlas level, connectivity data
%
% ASSUMPTIONS AND LIMITATIONS:
%   The data and mapping must come from the same run of the SBCI pipeline.
%
function [result] = parcellate_fc(data, sbci_parc, sbci_map, varargin)

p = inputParser;
addParameter(p, 'roi_mask', [], @isnumeric);

% parse optional variables
parse(p, varargin{:});
params = p.Results;

was_triangular = false;

% symmeterise the matrix for sorting
if istriu(data) || istril(data)
    was_triangular = true;
    data = data + data';
end

% sanity check
if ~issymmetric(data)
    error('Connectivity data must be triangular or symmetric')
end

% sort the matrix by ROI
data = data - diag(diag(data));
data = data(sbci_parc.sorted_idx, sbci_parc.sorted_idx);
data = triu(data);

% load and sort the labels by ROI
labels = sbci_parc.labels(sbci_parc.sorted_idx);
rois = unique(labels);

p = length(rois);
result = zeros(p, p);

% find the number of vertices each node represents and sort by ROI
areas = arrayfun(@(t) nnz(sbci_map.map(2,:)==t), unique(sbci_map.map(2,:)));
areas = areas(sbci_parc.sorted_idx);

% loop through upper triangular regions
for i = 1:(p-1)
    % find connectivity and area 
    % associated with the first ROI
    mask_a = (labels == rois(i));
    area_a = areas(mask_a);
    
    for j = (i+1):p
        % find connectivity and area 
        % associated with the second ROI
        mask_b = (labels == rois(j));
        area_b = areas(mask_b);
        
        % find the combined area of each pair of nodes
        area_ab = area_a' * area_b;
        
        % retrieve the connectivity of the two ROIs and perform a weighted
        % averge depending on the area covered be each pair of nodes
        roi_data = data(mask_a, mask_b);
        
        roi_data = atanh(roi_data);
        roi_data = sum(sum(roi_data .* area_ab)) / (sum(area_a) * sum(area_b));
        roi_data = tanh(roi_data);
        
        % finally, fill in the result
        result(i,j) = roi_data;
    end
end

% if the input was a full
% matrix, return a full matrix
if ~was_triangular
    result = result + result';
end

% remove any requested ROIs and return the result
mask = ~ismember(rois, params.roi_mask);
result = result(mask, mask);

end



