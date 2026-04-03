classdef IntermodalProblem < PROBLEM
    % =====================================================
    % 将论文中的 initModel.m 模型底座包装成 ALGORITHM/NSGAIIPlus
    % 可调用的 Problem 对象
    %
    % 关键兼容策略：
    % 1) 不重复定义 properties model
    % 2) 直接使用父类 PROBLEM 已继承的 obj.model
    % 3) 不依赖 PROBLEM 构造函数接收 'model', model
    % 4) 通过 getappdata(0, 'IntermodalProblem_model') 读取外部传入模型
    % =====================================================

    methods
        %% =========================
        % 0) 构造函数
        % 不向父类传 model，避免父类在 Setting 前丢失参数
        % =========================
        function obj = IntermodalProblem(varargin)
            obj = obj@PROBLEM(varargin{:});
        end

        %% =========================
        % 1) 问题设置
        % =========================
        function Setting(obj)

            % -------------------------------------------------
            % 从 appdata 读取外部脚本预先放入的 model
            % -------------------------------------------------
            mdl = getappdata(0, 'IntermodalProblem_model');

            if isempty(mdl)
                error(['IntermodalProblem: 未从 appdata 中读到 model。', newline, ...
                       '请在创建 problem 前先执行：', newline, ...
                       'setappdata(0, ''IntermodalProblem_model'', model);']);
            end

            % 将 model 写回对象
            obj.model = mdl;

            % ---- 目标维数 ----
            obj.M = obj.model.numOfObjs;

            % ---- 决策维数 ----
            obj.D = obj.model.numOfDecVariables;

            % ---- 种群规模 / 最大评价次数 ----
            obj.N = 100;
            obj.maxFE = 10000;

            % ---- 上下界 ----
            % 前半段：节点序列编码
            lower1 = ones(1, obj.model.numOfDecVariablesPart1);
            upper1 = obj.model.numOfDecVariablesPart1 * ones(1, obj.model.numOfDecVariablesPart1);

            % 后半段：运输方式整数编码
            lower2 = obj.model.lower2;
            upper2 = obj.model.upper2;

            obj.lower = [lower1, lower2];
            obj.upper = [upper1, upper2];

            % ---- 编码类型 ----
            % PlatEMO 常用约定：
            % 1=实数, 2=整数, 3=标签, 4=二进制, 5=排列
            obj.encoding = [5 * ones(1, obj.model.numOfDecVariablesPart1), ...
                            2 * ones(1, obj.model.numOfDecVariablesPart2)];
        end

        %% =========================
        % 2) 自定义初始化
        % 使用你的 initModel.m 里的初始化逻辑
        % =========================
        function Population = Initialization(obj, N)

            if nargin < 2
                N = obj.N;
            end

            PopDec = zeros(N, obj.D);

            for i = 1:N
                ind = obj.model.initIndividual(obj.model);
                PopDec(i, :) = ind;
            end

            Population = obj.Evaluation(PopDec);
        end

        %% =========================
        % 3) 决策变量修复
        % =========================
        function Dec = CalDec(obj, Dec)

            for i = 1:size(Dec, 1)
                Dec(i, :) = obj.model.repairIndividual(Dec(i, :), obj.model);
            end
        end

        %% =========================
        % 4) 目标函数计算
        % =========================
        function PopObj = CalObj(obj, Dec)

            n = size(Dec, 1);
            PopObj = zeros(n, obj.M);

            for i = 1:n
                ind = obj.model.repairIndividual(Dec(i, :), obj.model);
                [objs, ~] = obj.model.getIndividualObjs(ind, obj.model);
                PopObj(i, :) = objs;
            end
        end

        %% =========================
        % 5) 约束函数
        % 当前模型把不可行性通过 Big-M 罚进目标，
        % 所以这里返回全 0
        % =========================
        function PopCon = CalCon(obj, Dec)
            PopCon = zeros(size(Dec, 1), 1);
        end
    end
end