
load('./result/bestFitnessSetGa.mat');
load('./result/bestFitnessSetGaPlus.mat');

scope = 1: length(bestFitnessSetGaPlus);
semilogy(   scope, -bestFitnessSetGa(scope)', ...
            scope, -bestFitnessSetGaPlus(scope)', ...
        'LineWidth', 2);


title('Population Evolution Curve', 'Fontsize', 20);
legend('Ga', 'GaPlus');
xlabel('The Number Of Generations', 'Fontsize', 15);
ylabel('Total Cost', 'Fontsize', 15);
grid on;
drawnow;
