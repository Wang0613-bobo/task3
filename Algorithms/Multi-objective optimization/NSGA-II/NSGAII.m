classdef NSGAII < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm II

%------------------------------- Reference --------------------------------
% K. Deb, A. Pratap, S. Agarwal, and T. Meyarivan, A fast and elitist
% multiobjective genetic algorithm: NSGA-II, IEEE Transactions on
% Evolutionary Computation, 2002, 6(2): 182-197.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            crossoverRate = 0.6;                                                            % 交叉概率
            mutationRate = 0.01;                                                             % 变异概率
            populationSize = Problem.N;
            model = Problem.model;
            populationDec = initialPopulation(populationSize, model);                      % 初始化种群
            Population = Problem.Evaluation(populationDec);
            [~,FrontNo,CrowdDis] = EnvironmentalSelection(Population,Problem.N);
            
%             Y = Population.objs
%             Population.decs
            %% Optimization
            while Algorithm.NotTerminated(Population)
                MatingPool = TournamentSelection(2, Problem.N, FrontNo, -CrowdDis);
                OffspringDecs = newCrossoverOperation(Population(MatingPool).decs, crossoverRate, model);       % 交叉操作
                OffspringDecs = newMutationOperation(OffspringDecs, mutationRate, model);                       % 变异操作
                Offspring = Problem.Evaluation(OffspringDecs);
                [Population,FrontNo,CrowdDis] = EnvironmentalSelection([Population,Offspring],Problem.N);
            end
        end
    end
end