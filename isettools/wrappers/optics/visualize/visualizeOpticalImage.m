function visualizeOpticalImage(opticalImage, varargin)

p = inputParser;
p.addParameter('displayRetinalContrastProfiles', false, @islogical);
p.addParameter('displayRadianceMaps', true, @islogical);
% Parse input
p.parse(varargin{:});
displayRetinalContrastProfiles = p.Results.displayRetinalContrastProfiles;
displayRadianceMaps = p.Results.displayRadianceMaps;

% retrieve the spatial support of the scene(in millimeters)
spatialSupportMM = oiGet(opticalImage, 'spatial support', 'mm');
% Convert spatial support in degrees
optics = oiGet(opticalImage, 'optics');
focalLength = opticsGet(optics, 'focal length');
mmPerDegree = focalLength*tand(1)*1e3;
spatialSupportDegs = spatialSupportMM/mmPerDegree;


% retrieve the sRGB components of the optical image (just for visualization)
rgbImage = oiGet(opticalImage, 'rgb image');
% retrieve the XYZ tristimulus components of the optical image
XYZmap = oiGet(opticalImage, 'xyz');
xMap = squeeze(XYZmap(:,:,1))./sum(XYZmap,3);
yMap = squeeze(XYZmap(:,:,2))./sum(XYZmap,3);
% Compute mean chromaticity
meanChromaticity = [mean(xMap(:)) mean(yMap(:))];
optics = oiGet(opticalImage, 'optics');
opticsName = opticsGet(optics, 'name');
visualizeSceneRGB(spatialSupportDegs, 'degs', rgbImage, ...
    [], meanChromaticity, sprintf('retinal image using ''%s''', opticsName));

if (displayRadianceMaps)
    % retrieve the retinal irradiance (photon rate in photons/pixel/sec/nm)
    retinalImagePhotonRate = oiGet(opticalImage, 'photons');

    % retrieve wavelength support
    wavelengthSupport = oiGet(opticalImage, 'wave');
    wavelengthBandsToVisualize = 400:30:700;

    % Visualize radiance maps
    visualizeSceneRadiance(spatialSupportDegs, 'degs', ...
        retinalImagePhotonRate, wavelengthSupport, wavelengthBandsToVisualize);
end

% Visualize radiance contrast profiles
if (displayRetinalContrastProfiles) && (displayRadianceMaps)
    visualizeSceneRadiance(spatialSupportDegs, 'degs', ...
        retinalImagePhotonRate, wavelengthSupport, wavelengthBandsToVisualize, ...
        'contrastProfilesOnly', true);     
end

end
