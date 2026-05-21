# 城市出租车供需错配与空驶再平衡优化

**第一组**：23 信科 陈龙 · 22 光华 王溪斌 · 23 元培 汤平之

> 数值分析期末项目（2026 春）。
> 基于 NYC TLC Yellow Taxi 2024 Q1 公开行程数据的预测—优化模型。
>
> Repo：<https://github.com/Wangxibin123/numerical_methods_2026.git>

---

## 0. 一句话概括

> 用真实 NYC 出租车数据，先预测下一小时各 zone 需求，再求解空车再平衡 LP，
> 证明在与贪心调度持平的服务水平下，LP 把空驶距离成本平均压低 **15 %**
> （peak 小时最高 **5.5 倍**），并用 Monte Carlo 200 次需求扰动验证稳健。

## 1. 项目定位与分工原则

这是 **预测—优化** 项目，不是普通的「纽约出租车数据分析」。

```
真实行程数据 (TLC Parquet)
   │  Python 仅做这一段 ──┐
   ▼                      │
zone-hour 供需面板 (109k 行 × 19 列)
   │                      │
   ▼                      │
下一小时需求预测 (历史均值 / Ridge) ◄ 北太天元
   │
   ▼
空车调度线性规划 (linprog, λ ∈ [20, 42] 经济可辩护)
   │
   ▼
3 策略对比 (no-rebalance / greedy / LP) + λ 敏感性 + Monte Carlo
   │
   ▼
5 张图源 CSV → Python 渲 PNG → Beamer + auto-PPTX → 录音导 MP4
```

**严格分工**：
- **Python** 只做：parquet 下载/清洗/zone-hour 聚合/特征/cost 矩阵/数据校验，
  以及最后图像渲染、PPTX 拼装（无任何数值计算）。
- **北太天元 (Baltamatica 2025 社区版)** 做：预测、LP、greedy、no-rebalance、
  Monte Carlo、λ 敏感性 — 全部数学和优化。

## 2. 仓库结构（最新真实状态）

```
.
├── README.md                  ← 本文件
├── Makefile                   ← 一键 8 个 target
├── requirements.txt
├── .gitignore
│
├── data/
│   ├── raw/                   原始 parquet（git 排除，需下载）
│   │   └── README_download.md
│   ├── processed/             北太天元输入 CSV
│   │   ├── panel_numeric.csv          (109,250 × 19, 带 header)
│   │   ├── panel_numeric_noheader.csv (同上，不带 header)
│   │   ├── panel_columns.txt          (19 列名清单)
│   │   ├── top_zones.csv              (50 个 top zone id)
│   │   ├── zone_meta.csv              (zone_id / zone_name / borough)
│   │   ├── cost_matrix_topK.csv       (50 × 50 OD median 距离 mi)
│   │   └── test_hours.csv             (24 个测试小时)
│   └── README_data.md
│
├── code/
│   ├── python/                Python 8 脚本
│   │   ├── _config.py                 全局参数（路径、默认值）
│   │   ├── 00_config.py               独立运行的配置检查
│   │   ├── 01_download_tlc.py         下载 TLC parquet
│   │   ├── 02_preprocess_trips.py     清洗
│   │   ├── 03_build_features.py       聚合 + 特征
│   │   ├── 04_build_cost_matrix.py    cost 矩阵
│   │   ├── 05_optional_maps.py        可选地图（需 shapefile）
│   │   ├── 06_validate.py             11 项数据完整性断言
│   │   ├── 07_render_figures.py       仅渲 6 张 PNG
│   │   ├── 08_build_pptx.py           Beamer PNG + 讲稿 → pptx
│   │   └── run_preprocess.py          串 01→04
│   │
│   └── beita/                 北太天元 12 .m + 4 测试
│       ├── run_all.m                  一键 12 步主流水线
│       ├── config_project.m           α / λ / MC 次数 / 种子
│       ├── load_processed_data.m      fopen+fread+sscanf 快速 CSV 读
│       ├── split_train_test.m         验证 split_id
│       ├── predict_historical_mean.m  (zone, wd, hod) 三元组均值
│       ├── predict_ridge.m            闭式 Ridge
│       ├── build_rebalance_vectors.m  单小时 S/D/Q/P_true 构造
│       ├── solve_rebalance_lp.m       column-major LP → linprog
│       ├── greedy_rebalance.m         最近邻贪心
│       ├── evaluate_dispatch.m        真实 unmet/cost/srv 评估
│       ├── monte_carlo_robustness.m   200 次 Poisson 扰动
│       ├── export_figure_data.m       5 张图源 CSV
│       └── tests/
│           ├── test_lp_small_case.m
│           ├── test_no_deficit_case.m
│           ├── test_no_surplus_case.m
│           └── run_all_tests.m
│
├── results/
│   ├── tables/                所有数值产出（入 git，便于审阅）
│   │   ├── prediction_metrics.csv     预测精度
│   │   ├── dispatch_metrics.csv       24 小时 × 3 策略
│   │   ├── sensitivity_lambda.csv     20 个 λ × 24 小时聚合
│   │   ├── monte_carlo_metrics.csv    3 策略 mean/median/q95
│   │   ├── cleaning_summary.csv       逐步剩余行数
│   │   └── fig_data_*.csv             5 张图的源数据
│   └── figures/
│       ├── fig_demand_pattern.png
│       ├── fig_supply_demand_gap.png
│       ├── fig_dispatch_comparison.png    ★ 核心图
│       ├── fig_pareto_lambda.png          ★ λ 敏感性 + Pareto
│       ├── fig_monte_carlo_boxplot.png
│       └── fig_top_flows.png
│
├── report/
│   ├── report.tex             正文 4-5 页 + 附录 N（12pt + 1.5 行距）
│   └── report.pdf             ★ 编译产物
│
├── slides/
│   ├── main.tex               15 帧 16:9 Beamer
│   ├── main.pdf               ★ 编译产物
│   ├── narration.md           ★ 15 段中文讲稿（目标 21 min）
│   └── rendered/              slide-01..15.png（make pptx 自动生成）
│
├── ppt/
│   └── lecture.pptx           ★ make pptx 自动生成，15 帧 + 15 段讲者备注
│
├── video/
│   └── README_video_link.md   待团队填入 MP4 链接
│
└── docs/
    ├── reproduce.md           ★ 协作者一步步复现指南
    ├── division_of_labor.md   ★ 3 人详细任务清单
    ├── ai_usage.md            AI 工具使用声明
    ├── beita_usage_notes.md   北太天元 6 项兼容性踩坑
    ├── video_workflow.md      Beamer → PNG → PPT → MP4
    └── limitations.md         项目的诚实局限
```

★ = 直接交付物或最重要文档

## 3. 30 秒上手

整个项目通过 `make` 串联。**所有 target 都可独立运行**：

```bash
make all          # 一键全跑（30 min，含下载 600 MB）
make data         # 只跑 Python 数据预处理（含 11 项数据校验）
make experiment   # 只跑北太天元 LP + 渲图（数据已就位时约 30 s）
make report       # 编译 report.pdf
make slides       # 编译 slides/main.pdf
make pptx         # Beamer PDF → PNG → 自动塞进 ppt/lecture.pptx（含中文讲稿）
make video-prep   # 只渲 slide PNG（不更新 pptx）
make tests        # 跑 3 个北太天元 LP 单元测试，预期 passed 3/3
make clean        # 删 processed/ + results/ + LaTeX build
make distclean    # 上面 + raw/ + .venv/
```

## 4. 详细复现步骤

### 4.1 环境

| 工具 | 检测命令 |
| --- | --- |
| Python ≥ 3.10 | `python3 --version` |
| 北太天元 Baltamatica 2025 社区版 | `ls /Applications/Baltamatica.app` |
| XeLaTeX + ctex + latexmk | `xelatex --version` |
| Poppler `pdftoppm` | `pdftoppm -v` |
| PowerPoint（仅录音/导 MP4 阶段） | — |

### 4.2 第一步：数据预处理

```bash
make data
```

等价于：

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python code/python/01_download_tlc.py --year 2024 --months 1 2 3
.venv/bin/python code/python/02_preprocess_trips.py --year 2024 --months 1 2 3
.venv/bin/python code/python/03_build_features.py --topk 50
.venv/bin/python code/python/04_build_cost_matrix.py
.venv/bin/python code/python/06_validate.py
```

完成后 `data/processed/` 下 7 个 CSV + `cleaning_summary.csv`。
**11 项数据校验全过才能继续**。

### 4.3 第二步：北太天元主求解 + 渲图

```bash
make experiment
```

等价于：

```bash
printf "cd '$(pwd)/code/beita';\nrun_all;\nexit\n" \
  | /Applications/Baltamatica.app/Contents/MacOS/baltamaticaC.sh
.venv/bin/python code/python/07_render_figures.py
```

预期：
- `results/tables/` 多出 5 个 fig_data CSV + prediction/dispatch/sensitivity/monte_carlo
- `results/figures/` 6 张 PNG 全部刷新

### 4.4 第三步：单元测试（任何代码改动前必跑）

```bash
make tests
```

预期：`passed 3 / 3`。

### 4.5 第四步：编译 PDF

```bash
make report     # → report/report.pdf（8 页：正文 4-5 + 附录 A-N）
make slides     # → slides/main.pdf（15 帧 16:9）
```

### 4.6 第五步：生成可录音 PPTX

```bash
make pptx
```

→ `ppt/lecture.pptx`：15 张幻灯片，每张的 **讲者备注（Notes Pane）** 里
已经塞好对应的中文讲稿（从 `slides/narration.md` 自动同步）。

### 4.7 第六步：录视频（PowerPoint 手工）

打开 `ppt/lecture.pptx`：
1. View → Notes 看每页讲稿。
2. Slide Show → Record Slide Show → Record from Beginning。
3. 按 `docs/division_of_labor.md` 中的分工逐页录音 + 摄像头。
4. File → Export → Create Video → 1080p → Use Recorded Timings → 保存到 `video/final_video.mp4`。
5. 上传 LMS + 备份云盘后填 `video/README_video_link.md`。

详细：[docs/video_workflow.md](docs/video_workflow.md)。

## 5. 数学模型概要

样本单位 $(i, t)$：zone $i$，小时 $t$。

- **需求**：$P_{i,t}$ pickup count
- **供给代理**：$Q_{i,t}$ dropoff count（注意：不是真实空车库存）
- **缺口**：$D_{j,t+1}=\max(\widehat{P}_{j,t+1}-Q_{j,t},0)$
- **剩余供给**：$S_{i,t}=\max(Q_{i,t}-\widehat{P}_{i,t+1},0)$
- **成本**：$c_{ij}=$ 训练期 OD median trip_distance

**LP 再平衡**：

$$
\min_{x,u}\; \sum_{i,j} c_{ij}\,x_{ij}+\lambda\sum_j u_j
$$

s.t. $\sum_j x_{ij}\le S_i,\;\sum_i x_{ij}+u_j\ge D_j,\;x_{ij},u_j\ge 0$.

完整推导见 [report/report.tex](report/report.tex) §3。

## 6. λ 的经济学依据（不是拍脑袋）

λ 含义：**漏掉 1 个 trip 等价于多少英里空驶**（与 $c_{ij}$ 同量纲）。

从 NYC TLC 2024 Yellow Taxi 标准费率推导：

| 视角 | 推导 | λ (mi) |
| --- | --- | --- |
| 司机 | 单趟净收入 \$12 / 空驶单位成本 \$0.40/mi | ≈ 30 |
| 社会 | (\$12 + 客户机会成本 \$5) / \$0.40 | ≈ 42 |
| 平台 | 折扣率回报法 | ≈ 20–25 |

→ 可辩护区间 **λ ∈ [20, 42]**，默认取保守下界 **λ = 20**。

我们在 **20 个 λ 值 × 24 个测试小时 = 480 个 LP** 上做了 sensitivity sweep
（[results/tables/sensitivity_lambda.csv](results/tables/sensitivity_lambda.csv)）：
λ ≤ 5 几乎不调度，λ ∈ [10, 20] 是转折区，λ ≥ 20 完全饱和到 unmet=851.6 / srv=0.751。
整个可辩护区间 [20, 42] 都落在饱和带——**参数选择鲁棒**。

## 7. 评价指标

| 类别 | 指标 |
| --- | --- |
| 预测 | MAE、RMSE、sMAPE |
| 调度（用真实 $P^{\text{true}}_{t+1}$ 评估） | unmet_demand、empty_distance_cost、service_rate、reduction_rate、unit_improvement_cost |
| Monte Carlo | mean / median / q95 unmet、mean / q05 service_rate |

## 8. 预期结果（数值对照）

跑完 `make all` 后，下列数字应当 bit-for-bit 一致（rng 种子固定 20260521）：

| 量 | 期望 | 出处 |
| --- | --- | --- |
| panel 行数 | 109,250 | `06_validate.py` 报告 |
| 50 zones hour_index 全连续 | 是 | `06_validate.py` 第 4 项 |
| 历史均值 test MAE | 16.834 | `prediction_metrics.csv` |
| Ridge test MAE | 18.462 | 同上 |
| greedy 24h mean unmet | 845.0 | `sensitivity_lambda.csv` 列 8 |
| LP @ λ=20 mean unmet | 852.5 | `sensitivity_lambda.csv` λ=20 行 |
| greedy 24h mean cost (mi) | 3053.3 | `sensitivity_lambda.csv` 列 9 |
| LP @ λ=20 mean cost (mi) | 2596.6 | 同上 |
| LP 相对 greedy cost 降幅 | 15 % | (3053-2597) / 3053 |
| Monte Carlo LP mean unmet | 19.7 | `monte_carlo_metrics.csv` |
| Monte Carlo LP q05 srv | 0.9647 | 同上 |

## 9. 团队接手指南

按 **Modeling / Data / Presentation** 三个 lead 分工，工作量大致均衡。
详细清单：[docs/division_of_labor.md](docs/division_of_labor.md)。

| 成员 | 角色 | 主要负责 | 录视频 |
| --- | --- | --- | :---: |
| 22 光华 王溪斌 | Modeling Lead | LP / Ridge / 评估 / 北太天元 11 .m / λ 推导 / 报告 §1·§3·§4·§6 + 4 附录 / Makefile | ❌ |
| 23 信科 陈龙 | Data Lead | Python 7 数据脚本 + 数据校验 + Monte Carlo / 报告 §2·§5 + 4 附录 / Beamer P1–P8 录音 | ✅ |
| 23 元培 汤平之 | Presentation Lead | 图渲染 + PPTX 自动化 + 报告 & Beamer 排版 + 5 附录 + 4 文档 / Beamer P9–P15 录音 + MP4 后期 | ✅ |

录音对应到 slide 的详细映射：[docs/division_of_labor.md](docs/division_of_labor.md) 末尾的 Slide → 录制者对应表。

## 10. 现在还剩什么没做（待办）

| 任务 | 谁 | 文件 |
| --- | --- | --- |
| 录音 + 摄像头 | 陈龙 (P1-P8) + 汤平之 (P9-P15) | `ppt/lecture.pptx` |
| PowerPoint 导出 MP4 | 汤平之 | → `video/final_video.mp4` |
| 上传 MP4 到 LMS + 云盘 | 汤平之 | 填 `video/README_video_link.md` |

**所有代码、数据、报告 PDF、Beamer PDF、PPTX 已就绪并已 push。**

## 11. 局限

完整版见 [docs/limitations.md](docs/limitations.md)。简版：

1. dropoff 流只是供给代理，不是平台实时空车库存。
2. 没有天气、道路拥堵、大型活动等外生数据。
3. LP 是连续 relaxation，$x_{ij}$ 是期望调度强度，部署需取整。
4. 成本矩阵基于历史中位数，未考虑实时路况。
5. 假设调度瞬时执行，未模拟驾驶时延。
6. Ridge 不带 zone embedding，弱于强基线历史均值。

## 12. AI 工具使用声明

按课程要求公开，完整说明见 [docs/ai_usage.md](docs/ai_usage.md)。
本项目的数学建模、北太天元代码、清洗阈值、$\lambda$ 经济推导与实验解读
均由三人讨论完成；AI 工具仅在 Python / LaTeX 脚手架与样板格式上做过辅助，
所有产出均经过单元测试、scipy 镜像或人工对算验证。

北太天元社区版兼容性踩坑记录见 [docs/beita_usage_notes.md](docs/beita_usage_notes.md)（已全部 workaround，正常使用无需关心）。
