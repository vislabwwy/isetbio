function initSpace(obj,varargin)
% SPATIALRFINIT - Build spatial receptive fields for the bipolar mosaic
%
%    @bipolarMosaic.initSpace(varargin)
%
% Each bipolar mosaic takes its input from the cone mosaic, so that cell
% locations are with respect to the spatial samples of the cone mosaic. To
% compute the  spatial spread, we need to account for the cone spacing.
% Thus, if the cones are spaced, say 2 um, and the bipolar RF spans 5
% samples, the spatial extent will be 2*5 um. 
%
% Scientific notes and references
%
%  Size of the RF
%  Sampling density (stride) of the RF centers.
%
% --- REFERENCES AND BUILTIN bipolar types ---
%
% We have implemented five types of bipolar receptive fields, one assigned
% to each of the big five RGC types. Each bipolar type has a preferential
% cone selections.  The critical decision is no S-cones for on/off parasol
% and on-midget, as per the Chichilnisky primate data (REFERENCE HERE).
%
% N.B.  Parasol is synonymous with diffuse.
%
% The data for the support size is this passage from Dacey, Brainard, Lee,
% et al., Vision Research, 2000, page 1808 bottom right.
% (http://www.cns.nyu.edu/~tony/vns/readings/dacey-etal-2000.pdf)
%
% They write:
%
%  "The frequency response was bandpass and well fit by a difference of
%  Gaussians receptive field model. (abstract)"
%
%  "For midget bipolar cells, it is known that at retinal eccentricities up
%  to 10 mm virtually all cells restrict dendritic contact to single cones
%  (Milam et al., 1993; Wassle et al., 1994); this was confirmed for the
%  cell whose light response is illustrated in Fig. 4. B) Also see Boycott
%  & Wassle, 1991,  (European Journal of Neuroscience), Table 1."
%
%  On page 1809:
%   Center/Surround gain ratio is about 1:1.3 (area under the curve)
%   Surround:Center diameter about 1:10 (Center:surround)
%   They seem to think that for ganglion cells the gain ratio is about
%   1:0.5 and the diameter ratio is between 1:2 and 1:5.
%
% Likely the larger RF sizes measured physiological (Dacey et al.) vs
% anatomically (B&W) reflect spread of signals among cones (via direct gap
% junctions) and probably more important among cone bipolars (via gap
% junctions with AII amacrine cells). - Fred
%
% JRG/BW ISETBIO Team, 2015

%  PROGRAMMING TODO
%
% To compute the spread in microns from this specification, multiply the
% number of input samples by the spatial sample separation of the cones in
% the mosaic (stored in the input slot).
%
% We will incorporate a function that changes the size of the spread and
% support as a function of eccentricity.  For now we just put in some
% placeholder numbers. (Let's do better on this explanation, BW).
%
% When the layer is deeper, however, we have to keep referring back through
% multiple layers.  This issue will be addressed in the RGCLAYER, and then
% onward.
%
% We need to write simple utilities that convert from the spatial units on
% the cone mosaic into spatial units on the retinal surface (in um or mm).
% That will be first implemented in bipolar.plot('mosaic').  But basically,
% to do this the units are X*coneMosaic.patternSampleSize (we think).  This
% doesn't deal with the jittered cone mosaic yet, but kind of like this.
% (BW/JRG). 
% 



%% Parse inputs
p = inputParser;

p.addParameter('eccentricity',0,@isscalar);
p.addParameter('conemosaic',[],@(x)(isequal(class(x),'coneMosaic')));
p.addParameter('spread',1,@isscalar);
p.addParameter('stride',[],@(x)(isempty(x) || isscalar(x)));

% For the future.  We don't have multiple mosaics yet.
p.parse(varargin{:});

eccentricity = p.Results.eccentricity;
conemosaic   = p.Results.conemosaic;
spread       = p.Results.spread;
stride       = p.Results.stride;

%% Select parameters for each cell type

% The spatial samples below (e.g. minSupport and spread) are in units of
% samples on the cone mosaic.  We can convert this to spatial units on the
% cone mosaic (microns) by multiplying by the cone spatial sampling.  The
% cone mosaic is stored in the input slot of the bipolar mosaic.
switch obj.cellType
    
    case{'ondiffuse','offdiffuse','onparasol','offparasol'}
        % Diffuse bipolars that carry parasol signals
        %
        % ecc = 0 mm  yields 2x2 cone input to bp
        % ecc = 30 mm yields 5x5 cone input to bp
        
        minSupport = 12;   % Minimum spatial support
        
        % BW, screwing around.  Just arbitrarily set the spatial spread here.
        % Support formula extrapolated from data in Dacey ... Lee, 1999 @JRG to insert
        support = max(minSupport,floor(2 + (3/10)*(eccentricity)));
        
        % Standard deviation of the Gaussian for the center, specified in
        % spatial samples on the input mosaic.  Anywhere near the center
        % the input is basically 1 cone.  Far in the periphery, it will be
        % seomthing else that we will have a function for, like the
        % support.

        % We need an amplitude for these functions to be specified in the
        % object.
        obj.sRFcenter   = fspecial('gaussian',[support, support], spread);
        obj.sRFsurround = fspecial('gaussian',[support, support], 1.3*spread);
            
    case {'onsbc'}
        minSupport = 15;    % Minimum spatial support
        
        % Small bistratified cells - handle S-cone signals
        
        % Needs to be checked and thought through some more @JRG
        % for this particular cell type.
        support = max(minSupport,floor(2 + (3/10)*(eccentricity)));
        
        spread = 3;  % Standard deviation of the Gaussian - will be a function
        rfCenterBig   = fspecial('gaussian',[support,support],spread); % convolutional for now
        rfSurroundBig = fspecial('gaussian',[support,support],10*spread); % convolutional for now
        
        obj.sRFcenter   = rfCenterBig(:,:);
        obj.sRFsurround = rfSurroundBig(:,:);
        
        
    case{'onmidget','offmidget'}
        % Midget bipolars to midget RGCs
        
        minSupport = 7;    % Minimum spatial support
        
        % ecc = 0 mm yields 1x1 cone input to bp
        % ecc = 30 mm yields 3x3 cone input to bp
        % Support formula extrapolated from data in Dacey ... Lee, 1999 @JRG to insert
        
        support = max(minSupport,floor(1 + (2/10)*(eccentricity)));
        
        % Standard deviation of the Gaussian for the center.  Anywhere near
        % the center the input is basically 1 cone.  Far in the periphery,
        % it will be seomthing else that we will have a function for, like
        % the support.s
        spread = 1;
        obj.sRFcenter   = fspecial('gaussian',[support,support], spread); % convolutional for now
        obj.sRFsurround = 1.3*fspecial('gaussian',[support,support], 10*spread); % convolutional for now
        
end

% The bipolar RF center positions are stored with respect to the samples of
% the input layer (cone mosaic). The weights are also stored with respect
% to the input sample.

if isempty(stride), stride = round(spread); end

% Cone row and column positions, but centered around (0,0).
% These should be spaced by an amount that is controlled by a parameter and
% reflects the size of the receptive field.
[X,Y] = meshgrid(1:stride:conemosaic.cols,1:stride:conemosaic.rows);
X = X - mean(X(:)); Y = Y - mean(Y(:));

% Put them in the (row,col,X/Y) tensor.
obj.cellLocation = zeros(size(X,1),size(X,2),2);
obj.cellLocation(:,:,1) = X;
obj.cellLocation(:,:,2) = Y;

end
