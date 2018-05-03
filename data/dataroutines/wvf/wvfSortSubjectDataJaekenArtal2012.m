function [centralRefraction, emmetropes, myopes] = wvfSortSubjectDataJaekenArtal2012()

% Syntax:
%    [centralRefraction, emmetropes, myopes] = sortSubjectDataJaekenArtal2012()
%
% Description:
%    Analyze the central 5 degrees of individual Subject defocus zernike
%    coefficient for a given eye (mean central refraction, or Mc, in diopters) to sort 
%    Subjects as emmetrope (Mc between -0.75D and 1.0D) or myope (<
%    -0.75D). Hyperopic Subjects (Mc > 1.0D) are excluded (3 in total).
%    Pupil size was 4 mm in diameter.
%
%    Data are reported as Table 1 in the published article:
%    Jaeken, B. & Artal, P. (2012) Optical Quality of Emmetropic and Myopic
%    Eyes in the Periphery Measured with High-Angular Resolution. Investigative
%    Ophthalmology & Visual Science, June 2012, Vol. 53, No. 7
%
%       In Table 1, there are 6 groups + general Emmetrope versus Myope.
%           Group 1: Mc > 0.51 D
%           Group 2: 0.5 D > Mc > -0.49 D
%           Group 3: -0.5 D > Mc > -1.49 D
%           Group 4: -1.5 D > Mc > -2.49 D
%           Group 5: -2.5 D > Mc > -3.49 D
%           Group 6: Mc < -3.5 D
%
%    For information on Zernike coefficient and their names:
%    http://www.telescope-optics.net/monochromatic_eye_aberrations.htm

%    Table of names
%    =================================
%      j   name
%
%      0  'piston'
%      1  'vertical_tilt'
%      2  'horizontal_tilt'
%      3  'oblique_astigmatism'
%      4  'defocus'
%      5  'vertical_astigmatism'
%      6  'vertical_trefoil'
%      7  'vertical_coma'
%      8  'horizontal_coma'
%      9  'oblique_trefoil'
%      10 'oblique_quadrafoil'
%      11 'oblique_secondary_astigmatism'
%      12 'primary_spherical', 'spherical'
%      13 'vertical_secondary_astigmatism'
%      14 'vertical_quadrafoil'
%
% Inputs:
%    None.
%
% Outputs:
%    centralRefraction      - mean central refraction (Subjects x eyes x central 5 degrees eccen) (in
%                             diopters)
%    emmetropes             - struct with 2 fields, corresponding to indexing vectors (130 Subjects, RE;LE]), with a 1 for emmetropes
%    myopes                 - struct with 2 fields, corresponding to indexing vectors (130 Subjects, RE;LE]), with a 1 for myopes

% Optional key/value pairs:
%    None.

% Example:
% [centralRefraction, emmetropes, myopes] = wvfSortSubjectDataJaekenArtal2012;

% See also wvfLoadJaekenArtal2012Data

% First version of function: 05/03/2018 by EK (NYU)

%% 1. Load data from ISETBIO database
data = rawDataReadData('zCoefsJaekenArtal2012','datatype','isetbiomatfileonpath');
data = data.data;

%% 2. Define parameters to reshape and analyze dataset
totalZCoefs         = length(0:14);             % total number of zernike coefficients
totalSubjects       = 130;                      % total number of Subjects
totalEyes           = length({'right','left'}); % total number of eyes (used in this order, in the dataset, also known as OD - Oculus Dexter and OS - Oculus Sinister)
totalEccen          = length(-40:1:40);         % total number of measured central eccentricities (in degrees, 0 corresponds to fovea)

% whichEye            = {'right','left'};         % which eyes to analyze
eccen               = -2:2;                     % Central 5 degrees, fovea =0
j                   = 4;                        % Defocus coefficient equals J=4
pupilDiameterMM     = 4;                        % Pupil diameter in mm during measurement

cmap                = jet(6);                   % Article defines Subject data into 6 groups, colors are used below to mark the boundaries of these groups

% define thresholds for grouping Subjects:
threshEM            = -0.75;                    % Threshold (Diopters) that defines the cut off between Emmetropes (> -0.75) and Myopes (< -0.75)
thresh1             = [0.51 1];                 % Threshold (Diopters) that defines Group 1
thresh2             = [-0.49 0.5];              % Threshold (Diopters) that defines Group 2
thresh3             = [-1.49 -0.5];             % Threshold (Diopters) that defines Group 3
thresh4             = [-2.49 -1.5];             % Threshold (Diopters) that defines Group 4
thresh5             = [-3.49 -2.5];             % Threshold (Diopters) that defines Group 5
thresh6             = [-3.5 -6.5];              % Threshold (Diopters) that defines Group 6


%% 3. Truncate headers and reshape data
data = data(2:end,4:end);
data = reshape(data, totalZCoefs, totalSubjects, totalEyes, totalEccen); % zernike x subject x eye x eccentricity

%% 4. Analyze dataset
thisZCoef       = wvfOSAIndexToVectorIndex(j);      % since j index (OSA) starts from 0, and Matlab doesn't, we convert to vector index
eccenIdx        = find(ismember(-40:1:40, eccen));  % eccentricity indices

% Get subset of data corresponding to central 5 degrees, only defocus
cRefractionZ    = data(thisZCoef, :, :, eccenIdx);

% Convert zernike coefficients (um) to diopters. In the dataset the
% convention of negative numbers are used, so we multiply by -1
cRefractionD    = -1*zernikeDefocus2diopter(squeeze(cRefractionZ), pupilDiameterMM);

% exclude hyperopic Subjects (spherical refraction larger than 1D):
hyperopic       = any(nanmean(cRefractionD,3)>1.0,2); % should be Subjects [33, 44, 86];
cRefractionD(hyperopic,:,:) = NaN;

% Calculate the mean of the central five degrees for each eye
mcRE = nanmean(cRefractionD(:,1,:),3);
mcLE = nanmean(cRefractionD(:,2,:),3);


%% Visualize mean refraction per eye, with 6 groups as background colors

vcNewGraphWin([],'wide'); clf; hold all
fill([1,totalSubjects, totalSubjects, 1],[thresh1(1),  thresh1(1), thresh1(2), thresh1(2)], cmap(1,:));
fill([1,totalSubjects, totalSubjects, 1],[thresh2(1),  thresh2(1), thresh2(2), thresh2(2)], cmap(2,:));
fill([1,totalSubjects, totalSubjects, 1],[thresh3(1),  thresh3(1), thresh3(2), thresh3(2)], cmap(3,:));
fill([1,totalSubjects, totalSubjects, 1],[thresh4(1),  thresh4(1), thresh4(2), thresh4(2)], cmap(4,:));
fill([1,totalSubjects, totalSubjects, 1],[thresh5(1),  thresh5(1), thresh5(2), thresh5(2)], cmap(5,:));
fill([1,totalSubjects, totalSubjects, 1],[thresh6(1),  thresh6(1), thresh6(2), thresh6(2)], cmap(6,:));

% Plot the data per eye
plot(1:totalSubjects, mcRE', 'r-o','LineWidth',3);  
plot(1:totalSubjects, mcLE', 'k:o','LineWidth',3);

% Plot x = 0 line
plot(1:totalSubjects, zeros(1,totalSubjects), 'k', 'LineWidth',2);

% Plot Myope versus Emmetrope threhold
plot(1:totalSubjects, threshEM*ones(1,totalSubjects), 'k--','LineWidth',2);

% Label axes and legend
xlabel('Subject nr');
ylabel('Mean central refraction (Diopters)')
set(gca,'FontSize',20,'TickDir', 'out','TickLength', [0.015 0.015]);
title('Jaeken & Artal (2012) subject division into refractive groups')
h = findobj(gca);
legend(h(end:-1:2),{'GR1', 'GR2', 'GR3', 'GR4', 'GR5', 'GR6', ...
                      'Right eye (OD)', 'Left eye (OS)', ...
                      '0', 'Emmetrope/Myope Threshold'}, ...
                      'Location','bestoutside'); legend boxoff

axis([1 totalSubjects, thresh6(2) thresh1(2)]);

% Find indices for Myopes and Emmetropes
myopesIdxRE = find(mcRE < threshEM);
myopesIdxLE = find(mcLE < threshEM);

emmetropesIdxRE = find(mcRE >= threshEM);
emmetropesIdxLE = find(mcLE >= threshEM);

% Find indices for separate groups
group(1).idxRE = find(mcRE > thresh1(1));
group(1).idxLE = find(mcLE > thresh1(1));

group(2).idxRE = find((mcRE <= thresh2(2)) & (mcRE > thresh2(1))); 
group(2).idxLE = find((mcLE  <= thresh2(2)) & (mcLE > thresh2(1))); 

group(3).idxRE = find((mcRE <= thresh3(2)) & (mcRE > thresh3(1)));
group(3).idxLE = find((mcLE  <= thresh3(2)) & (mcLE > thresh3(1))); 

group(4).idxRE = find((mcRE <= thresh4(2)) & (mcRE > thresh4(1)));
group(4).idxLE = find((mcLE  <= thresh4(2)) & (mcLE > thresh4(1))); 

group(5).idxRE = find((mcRE <= thresh5(2)) & (mcRE > thresh5(1)));
group(5).idxLE = find((mcLE  <= thresh5(2)) & (mcLE > thresh5(1))); 

group(6).idxRE = find(mcRE  < thresh6(1));
group(6).idxLE = find(mcLE   < thresh6(1));

% Print out the group statistics mean +/- std, (#)
fprintf('\nReproduction of Table 1 Jaeken & Artal (2012):\n')
fprintf('Mc(diopters) Myopes RE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcRE(myopesIdxRE)), nanstd(mcRE(myopesIdxRE)), length(myopesIdxRE))
fprintf('Mc(diopters) Myopes LE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcLE(myopesIdxLE)), nanstd(mcLE(myopesIdxLE)), length(myopesIdxLE))

fprintf('Mc(diopters) Emmetropes RE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcRE(emmetropesIdxRE)),nanstd(mcRE(emmetropesIdxRE)), length(emmetropesIdxLE))
fprintf('Mc(diopters) Emmetropes LE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcLE(emmetropesIdxLE)),nanstd(mcLE(emmetropesIdxLE)), length(emmetropesIdxLE))

rd = randperm(length(emmetropesIdxLE),length(myopesIdxRE));

fprintf('Mc(diopters) Random selection of Emmetropes RE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcRE(emmetropesIdxLE(rd))),nanstd(mcRE(emmetropesIdxLE(rd))), length(emmetropesIdxLE(rd)))
fprintf('Mc(diopters) Random selection of Emmetropes LE: %1.2f +/- %1.2f, (%d)\n', nanmean(mcLE(emmetropesIdxLE(rd))),nanstd(mcLE(emmetropesIdxLE(rd))), length(emmetropesIdxLE(rd)))

for ii = 1:6
    fprintf('Mc(diopters) GR%d RE: %1.2f +/- %1.2f, (%d)\n', ii, nanmean(mcRE(group(ii).idxRE)), nanstd(mcRE(group(ii).idxRE)), length(group(ii).idxLE))
    fprintf('Mc(diopters) GR%d LE: %1.2f +/- %1.2f, (%d)\n', ii, nanmean(mcLE(group(ii).idxLE)), nanstd(mcLE(group(ii).idxLE)), length(group(ii).idxLE))
end

fprintf('Number of emmetropes: %d\n', length(unique([emmetropesIdxRE;emmetropesIdxLE])))
fprintf('Number of myopes: %d\n', length(unique([myopesIdxRE;myopesIdxLE])))

%% Return variables
centralRefraction = cRefractionD;
emmetropes.RE     = emmetropesIdxRE;
emmetropes.LE     = emmetropesIdxLE;
myopes.RE         = myopesIdxRE;
myopes.LE         = myopesIdxLE;

return

