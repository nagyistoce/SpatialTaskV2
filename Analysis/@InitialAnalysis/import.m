function obj = import(obj, eyePlot, debug, print)

if ~exist('debug', 'var')
    debug = true;
end
if ~exist('eyePlot', 'var')
    eyePlot = true;
end
if ~exist('print', 'var')
    print = true;
end

eN = numel(fields(obj.exp));
obj.expN = eN;

allData = [];
clear data
for e = 1:eN
    % Get subject field
    fn = obj.exp.(['s', num2str(e)]);
    if print; disp(['Loading ', fn]); end
    
    % Load psychophysics data
    a = load(fn);
    
    % Remove trials without responses
    % Using aStim field as it#s common to all versions and is populated on
    % response
    rmIdx = cellfun(@isempty, a.stimLog.aStim);
    a.stimLog = a.stimLog(~rmIdx,:);
    
    % Get number of available trials
    n = height(a.stimLog);
    if print; disp(['Loaded ', num2str(n), ' trials']); end
    
    % For all data, correct angle calculation from raw response
    newAngles = cellfun(@InitialAnalysis.calcAngle, ...
        a.stimLog.RawResponse, ...
        'UniformOutput', false);
    
    % And recalc diff angle
    da = cell2mat(a.stimLog.diffAngle);
    pos = mat2cell(a.stimLog.Position, ...
        ones(height(a.stimLog),1), 2);
    newDiffAngles = cellfun(@InitialAnalysis.diffAngle, ...
        pos, newAngles, ...
        'UniformOutput', false);
    
    % And respBinAn
    newRespBinAn = cellfun(@InitialAnalysis.calcRespBinAn, ...
        newAngles, ...
        'UniformOutput', false);
    
    if debug % Debug plots
        avNew = cell2mat(newAngles);
        av = cell2mat(a.stimLog.Angle);
        
        aNew = avNew(1:2:end);
        vNew = avNew(2:2:end);
        aOld = av(1:2:end);
        vOld = av(2:2:end);
        
        figure
        subplot(2,1,1)
        [yAOld, xAOld] = ksdensity(aOld, 'bandwidth', 2);
        plot(xAOld, yAOld)
        hold on
        [yANew, xANew] = ksdensity(aNew, 'bandwidth', 2);
        plot(xANew, yANew)
        title('Auditory responses')
        legend({'Uncorrected', 'Corrected'})
        subplot(2,1,2)
        [yVOld, xVOld] = ksdensity(vOld, 'bandwidth', 2);
        plot(xVOld, yVOld)
        hold on
        [yVNew, xVNew] = ksdensity(vNew, 'bandwidth', 2);
        plot(xVNew, yVNew)
        title('Visual responses')
        suptitle(['Subject: ', num2str(e), ...
            ' Corrected angle plot'])
        
        figure
        subplot(2,1,1)
        InitialAnalysis.plot180FFT(xAOld, yAOld)
        hold on
        InitialAnalysis.plot180FFT(xANew, yANew, ...
            'Auditory responses')
        subplot(2,1,2)
        InitialAnalysis.plot180FFT(xVOld, yVOld)
        hold on
        InitialAnalysis.plot180FFT(xVNew, yVNew, ...
            'Visual responses')
        suptitle(['Subject: ', num2str(e), ...
            ' Response angle regularity'])
    end
    
    % Sabe new values
    a.stimLog.diffAngle = newDiffAngles;
    a.stimLog.respBinAn = newRespBinAn;
    a.stimLog.Angle = newAngles;
    
    % TO DO:
    % Check respBinED
    % Seems to be same as respBinAn before angle correction??
    % Check calculation in task code
    % It's not generally used anyway
    % But in case, for now, set to be same as respBinAn
    a.stimLog.respBinED = newRespBinAn;
    
    % Process data according to version subject was run on
    % (swithces not mutually exclusive)
    % V1: S1 and S2
    switch fn
        case {obj.exp.s1, obj.exp.s2}
            % These two lack two columns present in later exps,
            % add dummies PossBinLog and PossBin
            
            poss = [-82.5, unique(a.stimLog.Position)', 82.5];
            
            a.stimLog.PosBinLog = cell(n,1);
            a.stimLog.PosBin = NaN(n,2);
            
            for t = 1:n
                a.stimLog.PosBinLog{t} = ...
                    [a.stimLog.Position(t,1) == poss; ...
                    a.stimLog.Position(t,2) == poss];
                
                a.stimLog.PosBin(t,:) = ...
                    [find(a.stimLog.PosBinLog{t}(1,:));...
                    find(a.stimLog.PosBinLog{t}(2,:))];
            end
    end
    
    % V2: S1-6
    switch fn
        case {obj.exp.s1, obj.exp.s2, obj.exp.s3, ...
                obj.exp.s4, obj.exp.s5, obj.exp.s6}
            % These need dummy timing columns
            n = height(a.stimLog);
            a.stimLog.timeStamp = NaN(n, 2);
            a.stimLog.startClock = ...
                repmat([1900, 1, 1, 1, 1, 1],n,1);
            a.stimLog.endClock = ...
                repmat([1900, 1, 1, 1, 1, 1],n,1);
    end
    
    % V3: - add eyedata if available
    % If not, adds placeholders
    % Available S7 onwards, but run for all
    switch fn
        case {obj.exp.s1, obj.exp.s2, obj.exp.s3, ...
                obj.exp.s4, obj.exp.s5, obj.exp.s6, obj.exp.s7}
            % Not using eye data
            % Give addEyeData2 some dummy params
            a.params = [];
            
        otherwise % Fututre exps (8 onwards)
            % From here, timesync info is available in params.
            % Need to load this.
            % Not using eye data from before this.
            % stimlog should contains gaze, not correctedGaze
            % any more.
            
            % No additional processing here at the moment
            % - handled in addEyeData2
    end
    
    % Add eye data
    [a.stimLog, gaze] = ...
        InitialAnalysis.addEyeData2(a.stimLog, ...
        obj.eye.(['s', num2str(e)]), ...
        a.params, ...
        eyePlot, ...
        print);
    if eyePlot
        title(['Subject ', num2str(e)]);
        xlabel('Time')
        ylabel('On target prop.')
    end
    
    % All subjects
    % Add a "correct" and "error" columns
    for r = 1:n
        a.stimLog.ACorrect(r,1) = ...
            all(a.stimLog.respBinAN{r,1}(1,:) ...
            ==  a.stimLog.PosBinLog{r,1}(1,:));
        a.stimLog.VCorrect(r,1) = ...
            all(a.stimLog.respBinAN{r,1}(2,:) ...
            ==  a.stimLog.PosBinLog{r,1}(2,:));
        
        a.stimLog.AError(r,1) = ...
            (find(a.stimLog.respBinAN{r,1}(1,:)) ...
            - find(a.stimLog.PosBinLog{r,1}(1,:))) * 15;
        a.stimLog.VError(r,1) = ...
            (find(a.stimLog.respBinAN{r,1}(2,:)) ...
            - find(a.stimLog.PosBinLog{r,1}(2,:))) * 15;
    end
    
    % Add subject number
    a.stimLog.Subject = repmat(e, n, 1);
    
    % Save subject data in structre and append to allData table
    data.(['s', num2str(e)]) = a.stimLog;
    gazeData.(['s', num2str(e)]) = gaze;
    allData = [allData; a.stimLog]; %#ok<AGROW>
    
    clear a gaze
end

% Back up imported data
obj.expDataS = data;
obj.expDataAll = allData;
obj.eyeDataS = gazeData;
end

function obj = applyGazeThresh(obj, print)

if ~exist('print', 'var')
    print = true;
end

% Reset
data = obj.expDataS;
allData = obj.expDataAll;

% Which onSurfProp to use?
osp = 'onSurfProp';
% Or
% osp = 'onSurfPropCorrectedED'; - removed

% Set thresh where there is eye data
thresh1 = 0.75;
% Set thresh where there isn't eye data -
% true = include all,
% false = discard all
thresh2 = true;

allOK = [];
for e = 1:obj.expN
    fieldName = ['s', num2str(e)];
    
    [data.(fieldName).onSurf, rs1, rs2] = ...
        InitialAnalysis.eyeIndex(data.(fieldName), ...
        osp, thresh1, thresh2);
    
    dataFilt.(fieldName) = ...
        data.(fieldName)(data.(fieldName).onSurf,:);
    
    % Lazy
    allOK = [allOK; data.(fieldName).onSurf]; %#ok<AGROW>
    
    if print
        disp('----')
        disp(fieldName)
        disp(rs1)
        disp(rs2)
        disp('----')
    end
end

allData.onSurf = allOK;

% Continue with data passing thresh only
obj.expDataS = dataFilt;
obj.expDataAll = allData(allData.onSurf==1,:);
