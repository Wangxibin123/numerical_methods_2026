# 城市出租车供需错配与空驶再平衡优化

**Demand–Supply Imbalance and Empty-Vehicle Rebalancing in Urban Taxi Systems**
**Based on NYC TLC Yellow Taxi Zone-Hour Data**

---

## 项目定位

这是一个 **预测—优化** 项目，不是普通的“纽约出租车数据分析”。

```
真实行程数据
   ↓
zone-hour 供需面板
   ↓
下一小时需求预测 (Ridge / Historical Mean)
   ↓
空车调度线性规划 (linprog)
   ↓
baseline 对比 (no-rebalance / greedy-nearest / LP)
   ↓
蒙特卡洛稳健性评估
```

数据来源：[NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page)

## 分工原则（重要）

- **Python** 只做：原始 Parquet 下载/清洗/zone-hour 聚合/特征工程/cost matrix/可选地图。
- **北太天元** 做：预测、LP 再平衡、greedy/no-rebalance baseline、Monte Carlo、敏感性、所有核心指标与图。

> 由于 NYC TLC 原始数据为大规模 Parquet 文件，北太天元直接读取与清洗 Parquet 不够方便，因此本文使用 Python 进行原始数据预处理；核心预测、线性规划再平衡、baseline 比较和蒙特卡洛稳健性分析均在北太天元中完成。

## 仓库结构

```
nyc-taxi-rebalancing/
├── README.md
├── requirements.txt
├── .gitignore
├── data/
│   ├── raw/                       Parquet 原始（git ignore）
│   ├── processed/                 北太天元输入 CSV
│   └── README_data.md
├── code/
│   ├── python/                    预处理脚本（仅）
│   │   ├── 00_config.py
│   │   ├── 01_download_tlc.py
│   │   ├── 02_preprocess_trips.py
│   │   ├── 03_build_features.py
│   │   ├── 04_build_cost_matrix.py
│   │   ├── 05_optional_maps.py
│   │   └── run_preprocess.py
│   └── beita/                     北太天元主求解
│       ├── run_all.m
│       ├── config_project.m
│       ├── load_processed_data.m
│       ├── split_train_test.m
│       ├── predict_historical_mean.m
│       ├── predict_ridge.m
│       ├── build_rebalance_vectors.m
│       ├── solve_rebalance_lp.m
│       ├── greedy_rebalance.m
│       ├── evaluate_dispatch.m
│       ├── monte_carlo_robustness.m
│       ├── make_core_figures.m
│       └── tests/
├── results/
│   ├── tables/
│   └── figures/
├── report/                        LaTeX 正文 6 页
├── slides/                        Beamer 16:9
├── ppt/                           PowerPoint 录音
├── video/                         MP4 链接说明
└── docs/
    ├── reproduce.md
    ├── ai_usage.md
    ├── division_of_labor.md
    ├── beita_usage_notes.md
    ├── limitations.md
    └── video_workflow.md
```

## 快速开始

### 第一步：Python 预处理

```bash
# 安装依赖
pip install -r requirements.txt

# 下载 2024-01 ~ 2024-03 Yellow Taxi（约 600MB）
python code/python/01_download_tlc.py --year 2024 --months 1 2 3 --taxi-type yellow

# 一键预处理（清洗 + zone-hour 聚合 + 特征 + cost matrix）
python code/python/run_preprocess.py --year 2024 --months 1 2 3 --topk 50
```

输出到 `data/processed/`：

```
panel_numeric.csv          带 header
panel_numeric_noheader.csv 不带 header（北太天元 csvread 用）
panel_columns.txt          列名清单
zone_meta.csv              zone_id / zone_name / borough
cost_matrix_topK.csv       K × K 行驶距离 OD 中位数
top_zones.csv              选中的 K 个 zone
test_hours.csv             测试时段列表
```

### 第二步：北太天元主求解

打开北太天元，定位到 `code/beita/`，执行：

```matlab
run_all
```

依次执行：
1. 读取 processed CSV
2. train/val/test 时间切分
3. 历史均值 baseline + Ridge 预测
4. 输出 `results/tables/prediction_metrics.csv`
5. 调度模拟：no-rebalance / greedy / LP
6. 输出 `results/tables/dispatch_metrics.csv`
7. λ 敏感性扫描
8. Monte Carlo 稳健性（默认 200 次）
9. 输出图：demand pattern / supply-demand gap / dispatch comparison / top flows / Monte Carlo boxplot

### 第三步：测试

北太天元中：

```matlab
cd tests
test_lp_small_case
test_no_deficit_case
test_no_surplus_case
```

### 第四步：报告与视频

- 编译报告：`cd report && latexmk -xelatex report.tex`
- 编译 Beamer：`cd slides && latexmk -xelatex main.tex`
- 转 PNG 后导入 PowerPoint 录音 → 导出 MP4，见 [docs/video_workflow.md](docs/video_workflow.md)

## 数学模型概要

样本单位 $(i, t)$：zone $i$，小时 $t$。

- 需求：$P_{i,t}$ pickup count
- 供给 proxy：$Q_{i,t}$ dropoff count
- 缺口：$D_{j,t+1}=\max(\widehat{P}_{j,t+1}-Q_{j,t},0)$
- 剩余供给：$S_{i,t}=\max(Q_{i,t}-\widehat{P}_{i,t+1},0)$
- 成本：$c_{ij}=$ 训练期 OD median trip_distance

LP：

$$
\min_{x,u}\;\;\sum_{i,j} c_{ij}x_{ij}+\lambda\sum_j u_j
$$

s.t. $\sum_j x_{ij}\le S_i,\;\sum_i x_{ij}+u_j\ge D_j,\;x_{ij},u_j\ge0$.

完整推导见 [report/report.tex](report/report.tex) 第 3 节。

## 评价指标

- 预测：MAE、RMSE、sMAPE
- 调度（使用 **真实** $P^{true}_{t+1}$）：unmet_demand、empty_distance_cost、reduction_rate、service_rate、unit_improvement_cost
- Monte Carlo：mean / median / q95 unmet、mean / q05 service_rate

## 局限（必须读）

见 [docs/limitations.md](docs/limitations.md)：

- dropoff flow 只是供给 proxy，并非真实空车库存
- 没有天气 / 道路拥堵 / 大型活动数据
- LP 是连续 relaxation，$x_{ij}$ 解释为期望调度强度
- 成本矩阵由历史 trip_distance 近似，未考虑实时路况

## AI 使用声明

见 [docs/ai_usage.md](docs/ai_usage.md)。

## 复现

见 [docs/reproduce.md](docs/reproduce.md)。
