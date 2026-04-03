function [result, algObj, info] = runAlgorithmAndGetResult(model)

    info = struct();
    info.execMode = '';
    info.resultSource = '';

    result = [];
    algObj = [];

    fprintf('\n----- 算法对象诊断 -----\n');

    % =====================================================
    % Step 1: 创建算法对象（无参构造）
    % =====================================================
    algObj = NSGAIIPlus();
    fprintf('class(algObj) = %s\n', class(algObj));

    try
        fprintf('properties(algObj):\n');
        disp(properties(algObj));
    catch
    end

    try
        fprintf('methods(algObj):\n');
        disp(methods(algObj));
    catch
    end

    % =====================================================
    % Step 2: 正式执行算法
    % 已确认接口为 Solve(obj, Problem)
    % =====================================================
    fprintf('调用方式：algObj.Solve(model)\n');
    algObj.Solve(model);

    info.execMode = 'algObj.Solve(model)';

    % =====================================================
    % Step 3: 读取结果
    % =====================================================
    if isempty(algObj.result)
        fprintf('\n----- 执行后对象状态 -----\n');
        disp(algObj);

        try
            fprintf('当前 algObj.result 内容：\n');
            disp(algObj.result);
        catch
        end

        try
            fprintf('当前 algObj.metric 内容：\n');
            disp(algObj.metric);
        catch
        end

        error('algObj.Solve(model) 已执行，但 algObj.result 仍为空。');
    end

    result = algObj.result;
    info.resultSource = 'algObj.result';

    fprintf('算法执行完成，结果已从 algObj.result 读取。\n');
end