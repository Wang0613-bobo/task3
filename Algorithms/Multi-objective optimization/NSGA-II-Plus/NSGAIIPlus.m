classdef NSGAIIPlus < ALGORITHM
% <multi> <real/integer/label/binary/permutation> <constrained/none>
% Nondominated sorting genetic algorithm II

%------------------------------- Reference --------------------------------
% K. Deb, A. Pratap, S. Agarwal, and K. Meyarivan, A fast and elitist
% multiobjective genetic algorithm: NSGA-II, IEEE Transactions on
% Evolutionary Computation, 2002, 6(2): 182-197.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference
% "Ye Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB
% platform for evolutionary multi-objective optimization [educational
% forum], IEEE Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            populationSize = Problem.N;
            model = Problem.model;
            populationDec = initialPopulation(populationSize, model);
            Population = Problem.Evaluation(populationDec);
            [~,FrontNo,CrowdDis] = EnvironmentalSelection(Population,Problem.N);

            crossoverRate0 = 0.6;
            mutationRate0  = 0.1;

            %% Optimization
            i = 0;
            while Algorithm.NotTerminated(Population)
                i = i + 1;
                D = 2;
                n = 1;
                [vUp, vDown] = getVUpAndVDown(i, D, n, 0);
                crossoverRate = crossoverRate0 * vDown;
                mutationRate  = mutationRate0 * vUp;

                for j = 1 : model.numOfDecVariables / 2
                    MatingPool    = TournamentSelection(2,Problem.N,FrontNo,-CrowdDis);
                    OffspringDecs = newCrossoverOperation(Population(MatingPool).decs, crossoverRate, model);
                    OffspringDecs = newMutationOperation(OffspringDecs, mutationRate, model);
                    Offspring     = Problem.Evaluation(OffspringDecs);
                    [Population,FrontNo,CrowdDis] = EnvironmentalSelection([Population,Offspring],Problem.N);
                    Problem.FE = Problem.FE - Problem.N;
                end
                Problem.FE = Problem.FE + Problem.N;
            end

            %% Task 3 stable export: save final population to MAT
            iSaveFinalPopulation(Population, Problem);
        end
    end
end

function iSaveFinalPopulation(Population, Problem)
    fprintf('[NSGAIIPlus] Task3 final-pop save stage started.\n');

    try
        saveFile = '';

        if isprop(Problem,'model') && ~isempty(Problem.model)
            if isfield(Problem.model, 'task3SaveFile')
                saveFile = Problem.model.task3SaveFile;
            end
        end

        if isempty(saveFile)
            outDir = fullfile(pwd, 'task3_output', 'final_population');
            if ~exist(outDir, 'dir')
                mkdir(outDir);
            end

            tau = NaN;
            Q = NaN;
            if isprop(Problem,'model') && ~isempty(Problem.model)
                if isfield(Problem.model, 'costOfUnitCarbon')
                    tau = Problem.model.costOfUnitCarbon;
                elseif isfield(Problem.model, 'carbonTax')
                    tau = Problem.model.carbonTax;
                end

                if isfield(Problem.model, 'quantityOfCargo')
                    Q = Problem.model.quantityOfCargo;
                elseif isfield(Problem.model, 'baseDemand')
                    Q = Problem.model.baseDemand;
                end
            end

            saveFile = fullfile(outDir, sprintf('finalPop_tau%.2f_Q%.0f.mat', tau, Q));
        end

        saveDir = fileparts(saveFile);
        if ~isempty(saveDir) && ~exist(saveDir,'dir')
            mkdir(saveDir);
        end

        fprintf('[NSGAIIPlus] Saving final population to: %s\n', saveFile);
        finalPopulation = Population; %#ok<NASGU>
        save(saveFile, 'finalPopulation');
        fprintf('[NSGAIIPlus] Save success.\n');

    catch ME
        fprintf(2, '[NSGAIIPlus] Save failed: %s\n', ME.message);
        for k = 1:numel(ME.stack)
            fprintf(2, '  at %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
    end
end
