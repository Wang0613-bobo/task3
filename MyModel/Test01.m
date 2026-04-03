fileName = './data/data037.txt';

[model] = initModel(fileName);
[individual] = model.initIndividual(model);
individual = [2,5,9,11,14,3,13,8,4,6,12,7,10,1,3,1,1,1,3,3,2,3,3,2,1,1];
[individualFitness] = model.getIndividualFitness(individual, model)
[path, typeOfPath] = model.analyseIndividual(individual, model)
% model.showIndividual(individual, model)

[distanceOfPath, distanceArray, numOfPenalty] = model.getDistanceOfPath(path, typeOfPath, model);
[pathTransferType] = model.getPathTransferType(typeOfPath);                 % 路线转运信息
[arriveTime, waitTime] = model.getArriveTime(distanceArray, typeOfPath, pathTransferType, model);
model.printIndividual(individual, model)
% find(~isnan(arriveTime) & arriveTime ~= inf)
% 等待成本
% 运输成本
% 碳排放量
% 中转成本
% 时间窗成本

