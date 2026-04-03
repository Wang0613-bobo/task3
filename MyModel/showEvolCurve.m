function showEvolCurve(startI, endI, bestFitnessSet)
% 展示种群进化曲线
    scope = startI: endI;
    semilogy(scope, bestFitnessSet(scope)', 'LineWidth', 2);
    
    title('Population Evolution Curve', 'Fontsize', 20);
    legend('Best Fitness');
    xlabel('The Number Of Generations', 'Fontsize', 15);
    ylabel('目标值', 'Fontsize', 15);
    grid on;
    drawnow;
end


