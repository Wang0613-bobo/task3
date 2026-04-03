function [PopObj] = getMultipleFitness(population, model)
% 计算种群适应度
    populationSize = size(population, 1);
    
    PopObj = [];
    for i = 1: populationSize
        individual = population(i, :);
        [individualObjs] = model.getIndividualObjs(individual, model);
        PopObj = [PopObj; individualObjs];
    end
end

