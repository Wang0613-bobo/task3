# task3

本仓库是一个 **MATLAB + PlatEMO** 的多式联运路径优化实验工程，用于支撑论文中的分任务实验（任务一/任务二/任务三）。

## 代码库作用（明确版）

- 以 `MyModel/initModel.m` 为模型底座，定义网络、运输方式、成本、碳排与目标函数接口。
- 以 PlatEMO 的 `PROBLEM/ALGORITHM` 机制驱动多目标优化（默认使用 `NSGAIIPlus`）。
- 支持参数扫描、Pareto 解后处理、代表性方案提取与结果导出（MAT/XLSX）。

一句话：

> 这是一个用于“多式联运路径在需求与碳税扰动下的多目标优化与结果分析”的实验平台。

## 关键入口

### 1) 模型底座
- `MyModel/initModel.m`
  - 初始化 OD 场景、网络数据、决策变量、成本/排放参数与评估函数句柄。

### 2) PlatEMO 问题封装
- `IntermodalProblem.m`
  - 将 `model` 封装成 PlatEMO 可求解问题。
  - 主要用于任务一/任务二脚本。

### 3) 任务脚本
- `run_task1_OD1_Q0_sweep.m`
  - 任务一：固定不确定参数，扫描需求规模 `Q0`，识别路径迁移。
- `run_task2_OD1_tax_sweep.m`
  - 任务二：固定需求，扫描 `carbonTax`，识别低碳替代。
- `run_task3_batch.m`
  - 任务三：支持单点调试 + 批处理；依赖“算法结束落盘最终种群”，再从 `.mat` 读取做后处理导出。
- `run_task3_reranking_analysis.m`
  - 任务三：对 `run_task3_batch` 输出的 `rerankingRows` 做重排链导出，生成主导方案切换表。

### 4) 任务三专用问题类
- `Problems/Multi-objective optimization/BT/myObj_task3.m`
  - 双目标：总成本（含碳税）+ 总排放。
  - 参数：`carbonTax`、`quantityOfCargo`（以及可选保存路径）。

### 5) 任务三稳定导出机制
- `Algorithms/Multi-objective optimization/NSGA-II-Plus/NSGAIIPlus.m`
  - 在 `main` 末尾保存 `finalPopulation` 到 `.mat`。
  - 目的：避免依赖 `platemo(...)` 返回值结构差异。

## 任务三推荐运行顺序

1. 打开 `run_task3_batch.m`，设置：
   - `doSinglePointOnly = true`（先单点验证）。
2. 在 MATLAB 运行：`run_task3_batch`。
3. 确认输出目录中生成：
   - `final_population/finalPop_tau*.mat`
   - `task3_plot_data.mat`
   - `task3_representative_table.xlsx`
   - `task3_summary_table.xlsx`
4. 单点稳定后，将 `doSinglePointOnly = false` 再批量运行。

## 结果文件说明（任务三）

- `finalPop_tau0.40_Q1000.mat`：每个参数点的最终种群。
- `task3_plot_data.mat`：后续绘图的聚合数据。
- `task3_representative_table.xlsx`：代表性解明细（CostBest/CarbonBest/Tradeoff）。
- `task3_summary_table.xlsx`：参数点级汇总。
- `task3_reranking_table.xlsx`：按轴分组的重排明细（含 Keep/Switch、主导驱动项）。
- `task3_dominance_switch_chain.xlsx`：仅包含 Switch 事件的主导方案替代表。

## 备注

- 当前仓库以脚本驱动实验为主，不是安装型工具包。
- 建议在 MATLAB 桌面环境运行，便于查看日志与中间结果。
