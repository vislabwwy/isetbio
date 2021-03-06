function [coneRFSpacing, coneRFDensity, rightEyeRetinalMeridianName] = coneRFSpacingAndDensity(obj, eccentricities, rightEyeVisualFieldMeridianName, eccUnits, densityUnits)
% Input
%   eccentricities      1-D vector with eccentricities (specified in eccUnits)
%   rightEyeVisualFieldMeridianName        name of the meridian in Watson's reference (visual
%                       field of the right eye, with temporal being at 0 degs
%                       superior at 90, nasal at 18, & inferior at 270 degs

    % Validate eccUnits
    obj.validateEccUnits(eccUnits);
    
    % Validate densityUnits
    obj.validateDensityUnits(densityUnits);
    
    % Make sure eccentricities is a 1xN vector
    if (size(eccentricities,1)>1)
        eccentricities = eccentricities';
    end
    assert(size(eccentricities,1) == 1, 'Eccentricities must be a 1xN vector');
    
    
    % Convert passed eccentricities to visual degs
    switch (eccUnits)
        case obj.visualDegsEccUnits
            % Convert ecc from degs to retinal MMs
            eccMM = obj.rhoDegsToMMs(eccentricities);
            eccDegs = eccentricities;
        case obj.retinalMMEccUnits
            eccMM = eccentricities;
            eccDegs = obj.rhoMMsToDegs(eccMM);
    end
    
    % Call the isetbio function coneSizeReadData to read-in the Curcio '1990
    % cone spacing/density data. 
    [isetbioAngle, whichEye, rightEyeRetinalMeridianName] = obj.isetbioRetinalAngleForWatsonMeridian(rightEyeVisualFieldMeridianName);
    fprintf('ISETBio angle for Watson''s ''%s'' (%s): %d\n', rightEyeVisualFieldMeridianName, rightEyeRetinalMeridianName, isetbioAngle);
    
    [~, ~, densityConesPerMM2] = coneSizeReadData('eccentricity', eccMM, ...
                                        'angle', isetbioAngle*ones(1,numel(eccMM)), ...
                                        'eccentricityUnits', 'mm', ...
                                        'angleUnits','deg', ...
                                        'whichEye', whichEye, ...
                                        'useParfor', false);
                                    
    % Apply correction for the fact that the isetbio max cone density (18,800 cones/deg^2) 
    % does not agree with Watson's (obj.dc0 =  14,804.6 cones/deg^2), and the fact that if we do not
    % apply this correction we get less than 2 mRGCs/cone at foveal eccentricities. We
    % apply this correction only for ecc <= 0.18 degs
    correctForFovealEcc = true;
    if (correctForFovealEcc)                                
        eccLimit = 0.18;
        
        WatsonModelMaxConeDensityPerDeg2 = obj.dc0;
        [~,~,ISETBioMaxConeDensityPerMM2] = coneSizeReadData('eccentricity', 0, 'angle', 0);
        ISETBioMaxConeDensityPerDeg2 = ISETBioMaxConeDensityPerMM2 * obj.alpha(0);
    
        correctionFactorMax = ISETBioMaxConeDensityPerDeg2 - WatsonModelMaxConeDensityPerDeg2;
        correctionFactorMax = correctionFactorMax / obj.alpha(0);
        
        idx = find(abs(eccDegs)<=eccLimit);
        if (~isempty(idx))
            indicesToBeCorrected = idx;
            correctionFactors = correctionFactorMax.*(eccLimit-eccDegs(indicesToBeCorrected))/eccLimit;
            densityConesPerMM2(indicesToBeCorrected) = densityConesPerMM2(indicesToBeCorrected) - correctionFactors;
        end
    end
    
    % In ConeSizeReadData, spacing is computed as sqrt(1/density). This is
    % true for a rectangular mosaic. For a hex mosaic, spacing = sqrt(2.0/(3*density)).
    spacingMM = sqrt(2.0./(sqrt(3.0)*densityConesPerMM2));
    spacingMeters = spacingMM * 1e-3;
     
    switch (densityUnits)
        case obj.retinalMMDensityUnits
            coneRFSpacing = spacingMeters * 1e3;
            coneRFDensity = densityConesPerMM2;
            
        case obj.visualDegsDensityUnits
            spacingMM = spacingMeters * 1e3;
            % Convert cone spacing in mm to cone spacing in degs at all eccentricities
            coneRFSpacing = obj.rhoMMsToDegs(spacingMM+eccMM)-obj.rhoMMsToDegs(eccMM); 
            
            % Convert cone density from per mm2 to per deg2
            % Compute mmSquaredPerDegSquared conversion factor for the
            % eccentricities (ecc specified in degs)
            mmSquaredPerDegSquared = obj.alpha(eccDegs);
            coneRFDensity = densityConesPerMM2 .* mmSquaredPerDegSquared;
    end
    
                                    
end

