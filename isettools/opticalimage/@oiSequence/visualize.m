function [uData, vObj] = visualize(obj,plotType,varargin)
% Visualize an OI sequence
%
% Syntax
%   oiSequence.visualize(plotType, ...);
%
% Description
%   This is a plot method for the oiSequence class.  The plot types
%   implemented are
%
% Inputs (required)
%   plotType - {'movie illuminance','movie rgb','weights','montage'}
%      movie illuminance - Gray scale (luminance) video of the stimulus
%      movie rgb -  Video of the stimuli
%      weights   -  Plot showing time series of weights
%      montage   -  Large montage of the frames and first panel of weights
%
% Optional key/value pairs
%   save      - Save a the movie  (boolean, false)
%   FrameRate - Frames per second (default 20)
%   vname     - Video file name when saving (default videoName);
%   showIlluminanceMap  -
%   eyeMovementsData    -  Show eye movement data (boolean, false)
%
% Return
%   uData - Displayed data
%   vObj  - Video object for movie case
%
% See also:  t_oisCreate

% History:
%                  NP/BW ISETBIO Team, 2016
%  01/06/18  dhb   Don't print text into command window.
%                  If we want text sometimes, add key/value 'verbose' pair
%                  and set default to false.

%% Interpret parameter values
p = inputParser;

p.addRequired('obj');
p.addRequired('plotType',@ischar);

% For video case ...
p.addParameter('vname','',@ischar);
p.addParameter('FrameRate',20,@isnumeric);

% Must ask NP more about this
p.addParameter('showIlluminanceMap', false, @islogical);
p.addParameter('eyeMovementsData', struct('show', false), @(x)(isstruct(x)&&(isfield(x,'show'))));

% Whether to use vcGraphWin or matlab's figure for rendering
p.addParameter('backendRenderer', 'vcGraphWin', @(x)(ischar(x)&&(ismember(x,{'vcGraphWin', 'figure'}))));

varargin = ieParamFormat(varargin);
p.parse(obj,plotType,varargin{:});

vname      = p.Results.vname;
FrameRate  = p.Results.FrameRate;

save = false;
if ~isempty(vname), save = true; end

%%  Show the oiSequence in one of the possible formats
uData = [];    % Returned data.
vObj  = [];    % Video object

switch ieParamFormat(plotType)
    case 'weights'
        % Graph the weights'
        vcNewGraphWin;
        plot(obj.timeAxis, obj.modulationFunction);
        xlabel('Time (ms)'); ylabel('Weight');
        title(sprintf('Composition: %s',obj.composition));
        grid on;
        uData.time = obj.timeAxis; 
        uData.wgts = obj.modulationFunction;
    case 'movieilluminance'
        % Show the oi as an illuminance movie
        wgts     = obj.modulationFunction;
        nFrames  = length(wgts);
        illFixed = oiGet(obj.oiFixed,'illuminance');
        illMod   = oiGet(obj.oiModulated,'illuminance');
        name     = oiGet(obj.oiModulated,'name');
        
        % This code is general, and it could become an obj.get.movie;
        % Or obj.get.illuminanceMovie
        % The algorithm for mixing these is problematic because we
        % calculate the max between the two scenes.  This normalization can
        % lead to unwanted problems (as it did for vernier coding).  I need
        % to have the data come here in real physical units and deal with
        % it appropriately.
        mx1 = max(illFixed(:)); mx2 = max(illMod(:));
        mx = max(mx1,mx2);
        d = zeros([size(illFixed),length(obj.timeAxis)]);
        
        % Monochrome image function, below, needs 0 256 by default, it seems
        illFixed = 256*illFixed/mx; illMod = 256*illMod/mx;
        
        switch obj.composition
            case 'blend'
                for ii=1:nFrames
                    d(:,:,ii) = illFixed*(1-wgts(ii)) + illMod*wgts(ii);
                end
            case 'add'
                for ii=1:nFrames
                    d(:,:,ii) = illFixed + illMod*wgts(ii);
                end     
            otherwise
                error('Unknown composition method: %s\n',obj.composition);
        end
        
        %  Show the movie data.  20Hz Frame rate.
        h = vcNewGraphWin; 
        colormap(gray(max(d(:)))); axis image; axis off;
        for ii=1:nFrames
            image(d(:,:,ii)); 
            axis image; title(name); drawnow;
            pause(0.05);
        end
        delete(h);
        
        uData.movie = d;

        % Write the video object if save is true
        if save
            %disp('Saving video ...')
            [~, vObj] = ieMovie(uData.movie,...
                'vname',vname,...
                'FrameRate',FrameRate,...
                'show',false);
            %disp('Done')
        end

    case 'moviergb'
        % Show the oi as an RGB movie
        wgts     = obj.modulationFunction;
        nFrames  = length(wgts);
        
        % I am not sure why this does not work as well with
        % oiGet(oi,'rgb');  There appears to be some scaling in that case
        % that shifts the means.
        xyzMod   = oiGet(obj.oiModulated,'xyz');
        xyzFixed = oiGet(obj.oiFixed,'xyz');
        rgbMod   = xyz2rgb(xyzMod);
        rgbFixed = xyz2rgb(xyzFixed);
        name     = oiGet(obj.oiModulated,'name');

        % Scale the RGB data to [0,1] with a common scale factor
        mx1 = max(rgbFixed(:)); mx2 = max(rgbMod(:)); mx = max(mx1,mx2);
        d = zeros([size(rgbFixed),length(obj.timeAxis)]);
        rgbFixed = rgbFixed/mx; rgbMod = rgbMod/mx;
        
        switch obj.composition
            case 'blend'
                % We think the mean of rgbFixed and mean of rgbMod should
                % probably be the same in this case.
                for ii=1:nFrames
                    d(:,:,:,ii) = rgbFixed*(1-wgts(ii)) + rgbMod*wgts(ii);
                end
            case 'add'
                for ii=1:nFrames
                    d(:,:,:,ii) = rgbFixed + rgbMod*wgts(ii);
                end     
            otherwise
                error('Unknown composition method: %s\n',obj.composition);
        end
        
        %  Show the movie data.  20Hz Frame rate.
        h = vcNewGraphWin; 
        axis image; axis off;
        for ii=1:nFrames
            % imagesc(d(:,:,:,ii),[0 256]); 
            image(d(:,:,:,ii)); 
            axis image; title(name); drawnow;
            pause(0.05);
        end
        delete(h);

        uData.movie = d;

        % Write the video object if save is true
        if save
            %disp('Saving video')
            [~, vObj] = ieMovie(uData.movie,...
                'vname',vname,...
                'FrameRate',FrameRate,...
                'show',false);
            %disp('Done')
        end

    case 'montage'
        % Window with snapshots and possibly eye movements.
        colsNum = round(1.3*sqrt(obj.length));
        rowsNum = round(obj.length/colsNum);
        subplotPosVectors = NicePlot.getSubPlotPosVectors(...
            'rowsNum', rowsNum, ...
            'colsNum', colsNum+1, ...
            'heightMargin',   0.05, ...
            'widthMargin',    0.02, ...
            'leftMargin',     0.04, ...
            'rightMargin',    0.00, ...
            'bottomMargin',   0.03, ...
            'topMargin',      0.03);
        
        if (p.Results.showIlluminanceMap)
            minIllum = Inf;
            maxIllum = -Inf;
            for oiIndex = 1:obj.length
                currentOI = obj.frameAtIndex(oiIndex);
                [illuminanceMap, ~] = oiCalculateIlluminance(currentOI);
                minIllum = min([minIllum min(illuminanceMap(:))]);
                maxIllum = max([maxIllum max(illuminanceMap(:))]);
            end
            if (minIllum == maxIllum)
                illumRange = [minIllum*0.99 maxIllum*1.01];
            else
                illumRange = [minIllum  maxIllum];
                meanIlluminance = mean(illumRange);
                illumMod = max(illumRange) / meanIlluminance - 1;
                illumRange = meanIlluminance + meanIlluminance*illumMod*[-1 1];
            end
        else
            XYZmax = 0;
            for oiIndex = 1:obj.length
                currentOI = obj.frameAtIndex(oiIndex);
                XYZ = oiGet(currentOI, 'xyz');
                if (max(XYZ(:)) > XYZmax)
                    XYZmax = max(XYZ(:));
                end
            end
            % Do not exceed XYZ values of 0.5 (for correct rendering)
            XYZmax = 2*XYZmax;
        end

        if strcmp(p.Results.backendRenderer,'vcGraphWin')
            h = vcNewGraphWin;
        else
            h = figure();
            uData.figHandle = h;
        end
        set(h, 'Color', [1 1 1], 'Position', [10 10 1700 730]); 
        for oiIndex = 1:obj.length
            if (oiIndex == 1)
                % Plot the modulation function
                subplot('Position', subplotPosVectors(1,1).v);
                bar(obj.timeAxis*1000, obj.modulationFunction, 0.9, 'LineWidth', 1.5, 'FaceColor', [1 0.5 0.5], 'EdgeColor', [1 0 0]);
                if (numel(obj.timeAxis)>1)
                    timeRange = [obj.timeAxis(1) obj.timeAxis(end)];
                else
                    timeRange = obj.timeAxis(1)+[-0.1 0.1];
                end
                set(gca, 'XLim', timeRange*1000, 'FontSize', 12);
                title(sprintf('composition: ''%s''', obj.composition));
                ylabel('modulation');
            end
            
            % Ask theOIsequence to return the oiIndex-th frame
            currentOI = obj.frameAtIndex(oiIndex);
            currentOIonsetTimeMillisecs = 1000*obj.timeAxis(oiIndex);
            dataXYZ = oiGet(currentOI, 'xyz');
            illuminanceMap = squeeze(dataXYZ(:,:,2));
            meanIlluminance = mean(illuminanceMap(:));
            %[illuminanceMap, meanIlluminance] = oiCalculateIlluminance(currentOI);
            support = oiGet(currentOI, 'spatial support', 'microns');
            xaxis = support(1,:,1);
            yaxis = support(:,1,2);
            row = 1+floor((oiIndex)/(colsNum+1));
            col = 1+mod((oiIndex),(colsNum+1));
            if (col > colsNum) || (row > rowsNum)
                continue;
            end
            subplot('Position', subplotPosVectors(row,col).v);
            if (p.Results.showIlluminanceMap)
                illuminanceMap = (illuminanceMap-illumRange(1))/(illumRange(2)-illumRange(1));
                imagesc(xaxis, yaxis, illuminanceMap);
                set(gca, 'CLim', [0 1]);
            else
                rgbImage = xyz2srgb(oiGet(currentOI, 'xyz')/XYZmax);
                imagesc(xaxis, yaxis, rgbImage, [0 1]);
            end

            axis 'image'
            if (col == 1) && (row == rowsNum)
                xticks = [xaxis(1) 0 xaxis(end)];
                yticks = [yaxis(1) 0 yaxis(end)];
                set(gca, 'XTick', xticks, 'YTick', yticks, 'XTickLabel', sprintf('%2.0f\n', xticks), 'YTickLabel', sprintf('%2.0f\n', yticks));
                ylabel('microns');
            else
                set(gca, 'XTick', [], 'YTick', [])
                xlabel(sprintf('frame %d (%2.1fms)', oiIndex, currentOIonsetTimeMillisecs));
            end
            
            if (p.Results.eyeMovementsData.show)
                hold on
                if (oiIndex < obj.length )
                    nextOIonsetTimeMillisecs = 1000*obj.timeAxis(oiIndex+1);
                else
                    nextOIonsetTimeMillisecs = 1000*(obj.timeAxis(oiIndex) +(obj.timeAxis(oiIndex)-obj.timeAxis(oiIndex-1)));
                end
            
                % plot eye movements during previous OIs in black
                idx = find(p.Results.eyeMovementsData.timeAxisMillisecs < currentOIonsetTimeMillisecs);
                plot(p.Results.eyeMovementsData.posMicrons(idx,1), p.Results.eyeMovementsData.posMicrons(idx,2), 'k.-');
                 % plot eye movements during current OI in red
                idx = find(...
                    p.Results.eyeMovementsData.timeAxisMillisecs >= currentOIonsetTimeMillisecs & ...
                    p.Results.eyeMovementsData.timeAxisMillisecs < nextOIonsetTimeMillisecs ...
                );
                plot(p.Results.eyeMovementsData.posMicrons(idx,1), p.Results.eyeMovementsData.posMicrons(idx,2), 'r.-');
                hold off;
            end
            
            if (p.Results.showIlluminanceMap)
                colormap(jet(1024));
            end

            title(sprintf('mean illum: %2.4f td', meanIlluminance));
            set(gca, 'FontSize', 12);
        end

    otherwise
        error('Unknown plot type %s\n',plotType);
end

end

