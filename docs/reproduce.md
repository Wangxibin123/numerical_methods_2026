# 复现说明 / Reproduce

> 目标：从空仓库出发，到最终的 `final_video.mp4`，每一步都能复现。

## 环境

| 工具 | 版本 |
| --- | --- |
| Python | ≥ 3.10 |
| pip | 任何近期版本 |
| 北太天元 | ≥ 2023 release（带 `linprog`） |
| LaTeX | XeLaTeX + latexmk + ctex |
| PowerPoint | 任何带 “Record Slide Show” 的近版 |

## 第一步 — Python 预处理

```bash
cd /path/to/数值分析大作业
pip install -r requirements.txt

# 一键串完整管线（下载 → 清洗 → 特征 → cost）
python code/python/run_preprocess.py --year 2024 --months 1 2 3 --topk 50

# 如已经手动下载好 parquet，跳过下载
python code/python/run_preprocess.py --skip-download --topk 50
```

完成后 `data/processed/` 下应该有：

```
panel_numeric.csv
panel_numeric_noheader.csv
panel_columns.txt
zone_meta.csv
top_zones.csv
cost_matrix_topK.csv
test_hours.csv
trips_clean.parquet
```

## 第二步 — 北太天元主求解

打开北太天元，命令行：

```matlab
cd /path/to/数值分析大作业/code/beita
run_all
```

终端能看到：
1. `[load] panel rows=... cols=... K=50 test_hours=24`
2. `[split] train=0.700 val=0.150 test=0.150`
3. `historical_mean test: MAE=... RMSE=... sMAPE=...`
4. `ridge test: ...`
5. 24 行 `hour XX: unmet no=... greedy=... lp=...`
6. λ 敏感性 6 行
7. Monte Carlo summary 3 行（no / greedy / lp）

写出 4 张表：

```
results/tables/prediction_metrics.csv
results/tables/dispatch_metrics.csv
results/tables/sensitivity_lambda.csv
results/tables/monte_carlo_metrics.csv
```

和 5 张图：

```
results/figures/fig_demand_pattern.png
results/figures/fig_supply_demand_gap.png
results/figures/fig_dispatch_comparison.png
results/figures/fig_top_flows.png
results/figures/fig_monte_carlo_boxplot.png
```

## 第三步 — 单元测试

```matlab
cd /path/to/数值分析大作业/code/beita/tests
run_all_tests
```

期望全部 3 个测试通过。

## 第四步 — 报告 / Beamer

```bash
cd report
latexmk -xelatex report.tex
# → report.pdf

cd ../slides
latexmk -xelatex main.tex
# → slides.pdf
```

## 第五步 — Slide → PNG → PPT → MP4

```bash
mkdir -p slides/rendered
pdftoppm -png -r 220 slides/slides.pdf slides/rendered/slide
```

接下来打开 PowerPoint：

1. 创建空白 16:9 PPT，将每张 PNG 作为全屏背景。
2. 每位同学按照 `docs/division_of_labor.md` 中分到的 slide 区间，
   逐页 “Record Slide Show” 录音 + 摄像头（头像放右下角）。
3. 出错时只重录对应 slide。
4. 录完后 “File → Export → Create Video → 1080p → Use Recorded Timings and Narrations”。
5. 输出到 `video/final_video.mp4`（git ignore），把链接放到
   `video/README_video_link.md`。

完整视频流程见 [video_workflow.md](video_workflow.md)。
