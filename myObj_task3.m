classdef myObj_task3 < PROBLEM
% Task-3 dedicated problem for intermodal optimization
% Objectives:
%   f1 = total cost (including carbon tax)
%   f2 = total emission

    methods
        function Setting(obj)
            % Parameter order:
            % 1) carbonTax
            % 2) quantityOfCargo
            % 3) odName
            % 4) networkFile
            % 5) saveFile (optional)
            % 6) demandUncertaintyRate (rho)
            % 7) confidenceLevel (alpha)
            % 8) scenarioConfig (optional)
            [carbonTax, quantityOfCargo, odName, networkFile, saveFile, rho, alpha, scenarioConfig] = ...
                obj.ParameterSet( ...
                    0.40, ...
                    1000, ...
                    'OD1', ...
                    fullfile('MyModel','data','wangluojiegou.txt'), ...
                    '', ...
                    0.20, ...
                    0.80, ...
                    struct());

            if isempty(networkFile)
                networkFile = fullfile('MyModel','data','wangluojiegou.txt');
            end
            if ~exist(networkFile,'file')
                networkFile = 'wangluojiegou.txt';
            end

            model = initModel(networkFile, odName);

            model.carbonTax = carbonTax;
            model.costOfUnitCarbon = carbonTax;

            model.baseDemand = quantityOfCargo;
            model.quantityOfCargo = quantityOfCargo;
            model.demandUncertaintyRate = rho;
            model.confidenceLevel = alpha;

            % 关键修复：将 scenarioConfig 真正写回模型，
            % 保证求解阶段与后处理阶段使用同一套需求场景配置。
            model = applyScenarioConfig(model, scenarioConfig);

            if ~isempty(saveFile)
                model.task3SaveFile = saveFile;
            end

            obj.model = model;
            obj.M = 2;
            obj.D = model.numOfDecVariables;
            obj.encoding = ones(1, obj.D) + 5;
        end

        function PopObj = CalObj(obj, PopDec)
            model = obj.model;
            n = size(PopDec,1);
            PopObj = nan(n,2);

            for i = 1:n
                individual = PopDec(i,:);
                [f,~] = iCallWithModel(model.getIndividualObjs, individual, model);
                PopObj(i,:) = f;
            end
        end
    end
end

function model = applyScenarioConfig(model, scenarioConfig)

    if isempty(scenarioConfig) || ~isstruct(scenarioConfig)
        return;
    end

    fieldNames = { ...
        'numDemandScenarios', ...
        'demandDistribution', ...
        'demandScenarioValues', ...
        'demandScenarioProb', ...
        'useCVaRAggregation', ...
        'riskBlend'};

    for i = 1:numel(fieldNames)
        f = fieldNames{i};
        if isfield(scenarioConfig, f)
            model.(f) = scenarioConfig.(f);
        end
    end
end

function varargout = iCallWithModel(funcHandle, varargin)
% Compatibility wrapper for signatures:
%   f(individual)
%   f(individual, model)
%   f(model, individual)

    errLog = {};

    try
        [varargout{1:nargout}] = funcHandle(varargin{:});
        return;
    catch ME
        errLog{end+1} = ME.message; %#ok<AGROW>
    end

    if numel(varargin) >= 2
        try
            [varargout{1:nargout}] = funcHandle(varargin{1});
            return;
        catch ME
            errLog{end+1} = ME.message; %#ok<AGROW>
        end

        try
            [varargout{1:nargout}] = funcHandle(varargin{2}, varargin{1});
            return;
        catch ME
            errLog{end+1} = ME.message; %#ok<AGROW>
        end
    end

    error('myObj_task3:CallFailed', ...
        'Function handle call failed. Tried signatures with errors:\n%s', ...
        strjoin(errLog, '\n---\n'));
end
