function [newPopulation] = newCrossoverOperation(population, crossoverRate, model)
    populationSize = size(population, 1);

    populationPart1 = population(:, 1: model.numOfDecVariablesPart1);
    populationPart2 = population(:, model.numOfDecVariablesPart1 + 1: end);
    
    newPopulationPart1 = crossoverOperationOfTsp(populationPart1, crossoverRate);	% 组合交叉操作
    newPopulationPart2 = crossoverOperation(populationPart2, crossoverRate);        % 实数交叉操作

    newPopulation = [newPopulationPart1, newPopulationPart2];
end

