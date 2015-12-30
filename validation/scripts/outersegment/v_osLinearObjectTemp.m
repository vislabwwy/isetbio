function varargout = v_osLinearObjectTemp(varargin)
%
% Validate the linear model of the cone outer segments.
%
% This script tests out our implementation of a biophysical model of the
% isomerizations to photocurrent transduction process that occurs in the
% cone outer segments.
%
% More specifically, this compares the linear based outer segment model output with several key
% measured properties of the cone photocurrent responses:
%   - impulse response in the dark
%   - responses to steps + flashes to measure kinetics of step response and
%     adaptation of step and flash responses
%   - responses to stimuli designed to mimic those encountered by a cone
%     during saccades about a natural scene
%   - responses to light increments and decrements
%
% References for original data:
%       Dunn et al. (2007)
%       Angueyra and Rieke (2013)
%
% At present, what this does is verify that the current outersegment object
% does the same thing as the routines from which it was built, namely those
% supplied by Fred.  This is really an interim step, as this just ensures
% that we didn't introduce any bugs when we built the object.  Once we have
% that checked, we can toss the old code and then validate what the
% outersegement object does directly against underlying measurements.
%
% 6/2015 FMR   Created.
% 7/2015 JRG   Test with ISETBIO outersegment object

    varargout = UnitTest.runValidationRun(@ValidationFunction, nargout, varargin);
end

%% Function implementing the isetbio validation code
function ValidationFunction(runTimeParams)

%% Init
ieInit;

%% Preferences group
validationPrefs = 'isetbioValidation';

%% Impulse response in dark
%
% We'll compare the original code and the outer segment object for this case.
%
% Set up parameters for stimulus.
nSamples = 2000;        % 2000 samples
timeStep = 1e-4;        % time step
flashIntens = 50000;    % flash intensity in R*/cone/sec (maintained for 1 bin only)

% Create human sensor.
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep); 

% Create stimulus.
stimulus = zeros(nSamples, 1);
stimulus(1) = flashIntens;
stimulus = reshape(stimulus, [1 1 nSamples]);

% Set photon rates.
sensor = sensorSet(sensor, 'photon rate', stimulus);

% Compute model current and baseline correct, using the old code.
params.bgVolts  = 0;
[~, adaptedCur] = coneAdapt(sensor, 'linear', params);
adaptedCur(:) = adaptedCur(:) - adaptedCur(:, :, nSamples);

% Create outersegment object and get the adapted response.
noiseFlag = 0; % or can be initialized with noise flag setting
adaptedOS = osLinear();
adaptedOS = osSet(adaptedOS, 'noiseFlag', noiseFlag);
sensor = sensorSet(sensor,'cone type', 2); % set L cone

% Compute the linear response.
%  Get the current and then subtract the offset voltage.
adaptedOS = osCompute(adaptedOS, sensor);
osAdaptedCur = osGet(adaptedOS, 'ConeCurrentSignal');
osAdaptedCur = osAdaptedCur - osAdaptedCur(:, :, nSamples);

% Make a plot of what happened using osPlot.
if (runTimeParams.generatePlots)   
    osPlot(adaptedOS, sensor);
end

% Plot a comparison of the two ways of doing it.
% These should be identical since we think they are the same code doing the same thing. 
if (runTimeParams.generatePlots)
    figure; clf; hold on
    tme = (1:nSamples)*timeStep;
    plot(tme,squeeze(adaptedCur),'r','LineWidth',4);
    plot(tme,squeeze(osAdaptedCur),'k:','LineWidth',2);
    xlabel('sec','FontSize',14);
    ylabel('pA','FontSize',14);
    title('impulse response in the dark','FontSize',16);
    legend('original code model resp', 'osLinear object resp');
end
tolerance = 1e-12;
UnitTest.assertIsZero(max(abs(adaptedCur-osAdaptedCur)),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);
clear adaptedOS paramsOS

%% Steps + flashes

% Set up parameters for stimulus.
stimPeriod = [4000 22000];          % start and end time of step
nSamples = stimPeriod(2)+4000;      % number of samples
timeStep = 1e-4;                    % time step
flashTime = stimPeriod - 3000;      % time of flashes
flashDur = 10;                      % flash duration (bins)
flashIntens = 10000;                % flash intensity R*/cone/sec

% Create human sensor.
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep);
sensor = sensorSet(sensor,'cone type', 2); % set s cone

% Set up plot
if (runTimeParams.generatePlots)   
    h1 = figure; clf;
    set(gcf,'Position',[100 100 1500 750]);
    subplot(1, 4, 1); hold on;
    subplot(1, 4, 2); hold on;
    subplot(1, 4, 3); hold on
    subplot(1, 4, 4); hold on;
end

% Go through series of step intensities (slow).
clear SSCur stimIntensity FlashAmp
FlashScFact = 1;
nStepIntensities = 11;
for step = 1:nStepIntensities
    
    % Create stimulus: step alone.
    stimIntensity(step) = 50 * 2^step;          
    stimulus = zeros(nSamples, 1);
    stimulus(stimPeriod(1):stimPeriod(2)) = stimIntensity(step);
    stimulus = reshape(stimulus, [1 1 nSamples]);
    
    % Increase flash strength if we are in range where cones are adapting.
    if (stimIntensity(step) > 4000);
        FlashScFact = FlashScFact * 2;
    end
    
    % Set photon rates.
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % Compute adapted current via old code.
    params.bgVolts  = 0;
    [~, adaptedCurStepOnly] = coneAdapt(sensor, 'linear', params);
    
    % Compute using outersegment object.
    noiseFlag = 0;
    adaptedOSStepOnly = osLinear();
    adaptedOSStepOnly = osSet(adaptedOSStepOnly, 'noiseFlag', noiseFlag);
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    adaptedOSStepOnly = osCompute(adaptedOSStepOnly, sensor);

    % Create stimulus: step + flash.
    stimulus = zeros(nSamples, 1);
    stimulus(stimPeriod(1):stimPeriod(2)) = stimIntensity(step);
    stimulus(flashTime(1):flashTime(1)+flashDur) = stimulus(flashTime(1):flashTime(1)+flashDur) + flashIntens;
    stimulus(flashTime(2):flashTime(2)+flashDur) = stimulus(flashTime(2):flashTime(2)+flashDur) + flashIntens*FlashScFact;
    stimulus = reshape(stimulus, [1 1 nSamples]);

    % Set photon rates.
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % Compute adapted current via old code.
    params.bgVolts  = 0;
    [~, adaptedCur] = coneAdapt(sensor, 'linear', params);
     
    % Compute using outersegment object.
    noiseFlag = 0;
    adaptedOS = osLinear();
    adaptedOS = osSet(adaptedOS, 'noiseFlag', noiseFlag);   
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    adaptedOS = osCompute(adaptedOS, sensor);

    % Plot
    if (runTimeParams.generatePlots)
        subplot(1, 4, 1);
        plot((1:nSamples)*timeStep, adaptedCur(:), 'r', 'lineWidth', 4);
        plot((1:nSamples)*timeStep, adaptedOS.ConeCurrentSignal(:), 'k', 'lineWidth', 2);

        subplot(1, 4, 2);
        plot((1:nSamples)*timeStep, adaptedCurStepOnly(:), 'r', 'lineWidth', 4);
        plot((1:nSamples)*timeStep, adaptedOSStepOnly.ConeCurrentSignal(:), 'k', 'lineWidth', 2);

        subplot(1, 4, 3);
        plot((1:nSamples)*timeStep, adaptedCur(:) - adaptedCurStepOnly(:), 'r', 'lineWidth', 2);
        temp = adaptedCur(:) - adaptedCurStepOnly(:);
        
        subplot(1, 4, 4);
        plot((1:nSamples)*timeStep, adaptedOS.ConeCurrentSignal(:) - adaptedOSStepOnly.ConeCurrentSignal(:), 'k', 'lineWidth', 2);
        tempOS = adaptedOS.ConeCurrentSignal(:) - adaptedOSStepOnly.ConeCurrentSignal(:);
    end

    % Summary measures.
    FlashAmp(step) = max(temp(flashTime(2):flashTime(2)+1000)) / (FlashScFact * max(temp(flashTime(1):flashTime(1)+1000)));
    SSCur(step) = -(adaptedCurStepOnly(1, 1, stimPeriod(2)) - adaptedCurStepOnly(1, 1, 1))/adaptedCurStepOnly(1, 1, 1);
    [MaxVal, MaxLoc] = max(temp(flashTime(2):flashTime(2)+1000));
    TPeak(step) = MaxLoc*timeStep;
    FlashAmpOS(step) = max(tempOS(flashTime(2):flashTime(2)+1000)) / (FlashScFact * max(tempOS(flashTime(1):flashTime(1)+1000)));
    SSCurOS(step) = -(adaptedOSStepOnly.ConeCurrentSignal(1, 1, stimPeriod(2)) - adaptedOSStepOnly.ConeCurrentSignal(1, 1, 1))/adaptedOSStepOnly.ConeCurrentSignal(1, 1, 1);
    
    % Get transient of step response, computed both ways.
    transientTme = stimPeriod(1)+round(6e-2/timeStep):stimPeriod(2);
    transient{step} = adaptedCurStepOnly(transientTme);
    transient{step} = transient{step} - transient{step}(end);
    transientOS{step} = adaptedOSStepOnly.ConeCurrentSignal(transientTme);
    transientOS{step} = transientOS{step} - transientOS{step}(end);
end

% Label plot
if (runTimeParams.generatePlots)
    subplot(1, 4, 1);
    xlabel('Time (sec)');
    ylabel('Photocurrent (pA)');
    title('Adapted Current');
    legend('original code', 'osLinear object','Location','NorthEast');

    subplot(1, 4, 2);
     xlabel('Time (sec)');
    ylabel('Photocurrent (pA)');
    title('Adapted Current Step Only');
    legend('original code', 'osLinear object','Location','NorthEast');
    
    subplot(1, 4, 3); 
    xlabel('Time (sec)');
    ylabel('Photocurrent (pA)');
    title('coneAdapt');

    subplot(1, 4, 4);
    xlabel('Time (sec)');
    ylabel('Photocurrent (pA)');
    title('osLinear object');
end

% Plot sensitivity vs background intensity relation
%
% Half desens around 2500 (Angueyra and Rieke, 2013)
if (runTimeParams.generatePlots)
    figure; clf; hold on;
    loglog(stimIntensity, FlashAmp, 'ro');
    loglog(stimIntensity, FlashAmpOS, 'kx');
    xlabel('Background');
    ylabel('Sensitivity');
    axis tight;
    legend('coneAdapt','osLinear');
end

% Plot transient from last step simulated
if (runTimeParams.generatePlots)
    figure; clf; hold on
    plot(transientTme, transient{end}(:),'r','Linewidth',4);%, tme, fit);
    plot(transientTme, transientOS{end}(:),':k','Linewidth',2);%, tme, fit);
    xlabel('Time (sec)');
    ylabel('Photocurrent (pA)');
    title('Transient for largest step');
    legend('coneAdapt','osLinear');
end

% Save validation data
tolerance = 1e-12;
UnitTest.assertIsZero(max(abs(FlashAmp(:)-FlashAmpOS(:))),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);
clear adaptedOS adaptedOSSteponly paramsOS paramsOSStepOnly

%% Saccade-like stimuli

% Load experimental data using RDT.
client = RdtClient(getpref(validationPrefs,'remoteDataToolboxConfig'));
client.crp('resources/data/experimental/cones');
[eyeMovementExample, eyeMovementExampleArtifact] = client.readArtifact('eyeMovementExample', 'type', 'mat');

% Get mean subtracted current and stimulus from read data
measuredCur = eyeMovementExample.data.Mean - eyeMovementExample.data.Mean(length(eyeMovementExample.data.Mean));
stimulus = eyeMovementExample.data.Stim;
nSamples = length(stimulus);
stimulus = reshape(stimulus, [1 1 nSamples]);

% Compute adapted current using DEQ model.

% Create human sensor.
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', 5e-5);

% Set photon rates.
sensor = sensorSet(sensor, 'photon rate', stimulus);


sensor = sensorSet(sensor,'cone type', 2); % set s cone

% Compute adapted current.
params.bgVolts  = 0;
[~, adaptedCur] = coneAdapt(sensor, 'linear', params);
% adaptedCur = adaptedCur - adaptedCur(:, :, length(stimulus));

% Create outersegment object.
noiseFlag = 0;
adaptedOS = osLinear();
adaptedOS = osSet(adaptedOS, 'noiseFlag', noiseFlag);

adaptedOS = osCompute(adaptedOS, sensor);

osAdaptedCur = osGet(adaptedOS, 'ConeCurrentSignal');
% osAdaptedCur = osAdaptedCur - osAdaptedCur(:, :, nSamples);

% Plot against measurement data.
% if (runTimeParams.generatePlots)
figure(5); 
clf;
% subplot(1,2,1);
hold on;
% plot((1:nSamples)*5e-5, measuredCur(1,:));
plot((1:nSamples)*5e-5, adaptedCur(:), 'r', 'LineWidth', 3);
axis tight
xlabel('sec');
ylabel('pA');
title('coneAdapt');

% subplot(1,2,2);
hold on;
% plot((1:nSamples)*5e-5, measuredCur(1,:));
plot((1:nSamples)*5e-5, osAdaptedCur(:), 'k:', 'LineWidth', 2);
axis tight
xlabel('sec');
ylabel('pA');
title('osLinear');
legend('coneAdapt','osLinear');

% end

tolerance = 1e-11;
UnitTest.assertIsZero(max(abs(adaptedCur-osAdaptedCur)),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);


% clear adaptedOS paramsOS
%% Increment/decrement asymmetry

% Set up parameters for stimulus.
stimPeriod = [5000 7500]; % start and end time of step
nSamples = stimPeriod(2)+5000;
timeStep = 2e-4;
Contrast = 1;

% Create human sensor.
sensor = sensorCreate('human');
sensor = sensorSet(sensor, 'size', [1 1]); % only 1 cone
sensor = sensorSet(sensor, 'time interval', timeStep);

figure(1); clf;
clear MaxInc MaxDec stimIntensity;

% Predict responses to increments and decrements across range of light
% levels.
for step = 1:7
    
    % Create stimulus: step alone.
    stimIntensity(step) = 250 * 2^step;          % photons per second
    stimulusInc = zeros(nSamples, 1);
    stimulusInc(100:nSamples-100) = stimIntensity(step);
    stimulusInc(stimPeriod(1):stimPeriod(2)) = stimIntensity(step)*(1 + Contrast);
    stimulus = reshape(stimulusInc, [1 1 nSamples]);

    % Set photon rates.
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % Compute adapted current.
    params.bgVolts  = 0;
    [~, adaptedCurInc] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object.
    noiseFlag = 0;
    adaptedOSInc = osLinear();
    adaptedOSInc = osSet(adaptedOSInc, 'noiseFlag', noiseFlag);  
    sensor = sensorSet(sensor,'cone type', 2); % set s cone
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    adaptedOSInc = osCompute(adaptedOSInc, sensor);
    
    % Create stimulus: step + flashes.
    stimulusDec = zeros(nSamples, 1);
    stimulusDec(100:nSamples-100) = stimIntensity(step);
    stimulusDec(stimPeriod(1):stimPeriod(2)) = stimIntensity(step)*(1 - Contrast);
    stimulus = reshape(stimulusDec, [1 1 nSamples]);

    % Set photon rates.
    sensor = sensorSet(sensor, 'photon rate', stimulus);

    % Compute adapted current.
    params.bgVolts  = 0;
    [~, adaptedCurDec] = coneAdapt(sensor, 'linear', params);
    
    % Create outersegment object.
    noiseFlag = 0;
    adaptedOSDec = osLinear();
    adaptedOSDec = osSet(adaptedOSDec, 'noiseFlag', noiseFlag);  
    
    sensor = sensorSet(sensor,'adaptation offset',params.bgVolts);
    adaptedOSDec = osCompute(adaptedOSDec, sensor);
    
    osAdaptedCur = osGet(adaptedOS, 'ConeCurrentSignal');

    % Summary measures.
    MaxInc(step) = adaptedCurInc(1, 1, stimPeriod(2)-1) - adaptedCurInc(1, 1, stimPeriod(1)-1);
    MaxDec(step) = adaptedCurDec(1, 1, stimPeriod(2)-1) - adaptedCurDec(1, 1, stimPeriod(1)-1);
    
    MaxOSInc(step) = adaptedOSInc.ConeCurrentSignal(1, 1, stimPeriod(2)-1) - adaptedOSInc.ConeCurrentSignal(1, 1, stimPeriod(1)-1);
    MaxOSDec(step) = adaptedOSDec.ConeCurrentSignal(1, 1, stimPeriod(2)-1) - adaptedOSDec.ConeCurrentSignal(1, 1, stimPeriod(1)-1);
    
    % if (runTimeParams.generatePlots)
    % plot
    subplot(1,2,1);
    plot((1:nSamples)*timeStep, adaptedCurInc(:), (1:nSamples)*timeStep, adaptedCurDec(:));
    pause(0.1);
    
    subplot(1,2,2);
    plot((1:nSamples)*timeStep, adaptedOSInc.ConeCurrentSignal(:), (1:nSamples)*timeStep, adaptedOSDec.ConeCurrentSignal(:));
    pause(0.1);
    % end % generatePlots
end

% if (runTimeParams.generatePlots)

subplot(1,2,1); title('coneAdapt');
subplot(1,2,2); title('osLinear');
    
figure(2); 
clf
% subplot(1,2,1);
semilogx(stimIntensity, -MaxDec ./ MaxInc, 'ro');
xlabel('background');
ylabel('dec/inc');
title('coneAdapt');

% subplot(1,2,2);
hold on;
semilogx(stimIntensity, -MaxOSDec ./ MaxOSInc, 'kx');
xlabel('background');
ylabel('dec/inc');
% title('osLinear');
legend('coneAdapt','osLinear');

% end %generatePlots

tolerance = 1e-12;
UnitTest.assertIsZero(max(abs((-MaxDec ./ MaxInc)-(-MaxOSDec ./ MaxOSInc))),'Comparison for dark impulse response',tolerance);
UnitTest.validationData('adaptedCur',adaptedCur);
UnitTest.validationData('osAdaptedCur',osAdaptedCur);

end
