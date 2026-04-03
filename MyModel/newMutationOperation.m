function [newPopulation] = newMutationOperation(population, mutationRate, model)
    populationPart1 = population(:, 1: model.numOfDecVariablesPart1);
    populationPart2 = population(:, model.numOfDecVariablesPart1 + 1: end);
    
    newPopulationPart1 = mutationOperationOfTsp(populationPart1, mutationRate);                     % 组合变异操作
    newPopulationPart2 = mutationOperationOfReal(populationPart2, mutationRate, model);                  % 实数变异操作
    
    newPopulation = [newPopulationPart1, newPopulationPart2];
end

