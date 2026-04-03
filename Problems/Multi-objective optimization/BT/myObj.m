classdef myObj < PROBLEM
% <multi> <real> <large/none> <expensive/none>
% Benchmark MOP proposed by Zitzler, Deb, and Thiele

%------------------------------- Reference --------------------------------
% E. Zitzler, K. Deb, and L. Thiele, Comparison of multiobjective
% evolutionary algorithms: Empirical results, Evolutionary computation,
% 2000, 8(2): 173-195.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        %% Default settings of the problem
        function Setting(obj)
           % 通过 PlatEMO 参数机制接收碳税（单位：元/kg-CO2）
            [carbonTax] = obj.ParameterSet(0.05);

            fileName = fullfile('MyModel','data','wangluojiegou.txt');
            if ~exist(fileName,'file')
                fileName = 'wangluojiegou.txt';
            end
            model = initModel(fileName);
            model.carbonTax = carbonTax;

            obj.model = model;
            obj.M = model.numOfObjs;
            obj.D = model.numOfDecVariables;
            obj.encoding = ones(1,obj.D) + 5;
        end
        %% Calculate objective values
        function PopObj = CalObj(obj, PopDec)
            model = obj.model;
            [PopObj] = getMultipleFitness(PopDec, model);
        end

    end
end