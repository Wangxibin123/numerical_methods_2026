# 复现说明 — 给协作者的逐步指南

> 目标：克隆仓库后 \~20 分钟内能复现出全部表 + 全部图 + 报告 PDF + Beamer PDF。

## 0. 环境检查

| 工具 | 版本要求 | 检测命令 |
| --- | --- | --- |
| Python | ≥ 3.10 | `python3 --version` |
| Baltamatica（北太天元） | 2025 社区版 | 打开 `/Applications/Baltamatica.app` 验证 |
| XeLaTeX + ctex + latexmk | 任何近版 TeX Live | `xelatex --version`, `latexmk --version` |
| make | macOS / Linux 自带 | `make --version` |
| Poppler `pdftoppm` | 任何近版 | `pdftoppm -v` |
| PowerPoint | 任何近版（仅最终视频合成） | — |

## 1. 克隆仓库

```bash
git clone git@github.com:Wangxibin123/numerical_methods_2026.git nyc-taxi-rebalancing
cd nyc-taxi-rebalancing
```

## 2. 一键运行（推荐）

```bash
make all
```

依次执行：
1. `make venv` — 创建 `.venv/`，pip install requirements
2. `make data` — 下载 + 清洗 + 特征 + cost matrix + **校验**
3. `make experiment` — 北太天元 LP 流水线 + Python 渲图
4. `make report` — 编译 `report/report.pdf`
5. `make slides` — 编译 `slides/main.pdf`

## 3. 分步运行（出问题时排查用）

### 3.1 数据下载与预处理

```bash
make venv
make data
```

预期输出：

```
data/processed/
├── panel_numeric.csv          # 109,250 rows × 19 cols
├── panel_numeric_noheader.csv # 同上，无 header
├── panel_columns.txt
├── zone_meta.csv              # 50 zones × {id, name, borough}
├── top_zones.csv              # 50
├── cost_matrix_topK.csv       # 50 × 50
├── test_hours.csv             # 24
└── trips_clean.parquet        # ~9.18M trips, ~280 MB
```

并跑 11 项数据完整性断言（详见 `code/python/06_validate.py`）。

如果数据校验失败 → **不要继续往下跑**，先排查 Python 端的清洗与特征代码。

### 3.2 北太天元 LP 流水线

```bash
make experiment
```

等价于：

```bash
printf "cd '$(pwd)/code/beita';\nrun_all;\nexit\n" \
  | /Applications/Baltamatica.app/Contents/MacOS/baltamaticaC.sh
.venv/bin/python code/python/07_render_figures.py
```

预期输出（关键行）：

```
[load] panel rows=109250 cols=19  K=50  test_hours=24
[split] train=0.700 val=0.150 test=0.150 (target 0.70/0.15/0.15)
historical_mean test: MAE=16.834 RMSE=28.907 sMAPE=0.3064
ridge           test: MAE=18.462 RMSE=29.785 sMAPE=0.4050 (alpha=1.00)
...
== run_all done ==
```

完成后 `results/tables/` 应有 8 个 CSV，`results/figures/` 应有 6 个 PNG。

### 3.3 报告与 Beamer

```bash
make report      # → report/report.pdf  (8 页)
make slides      # → slides/main.pdf    (14 页)
```

中文渲染依赖 `ctex` 包。如果首次编译报缺字体，可在 macOS 上：

```bash
sudo tlmgr install ctex xecjk
```

### 3.4 单元测试

```bash
make tests
```

预期输出：`passed 3 / 3`。

## 4. 视频流程（仅 final video 阶段）

```bash
make video-prep
# 然后用 PowerPoint 打开 slides/rendered/*.png
# 按 slides/narration.md 录每页讲稿
# Export → Create Video → 1080p → final_video.mp4
```

完整步骤见 [video_workflow.md](video_workflow.md)。

## 5. 数据导入给协作者（关键）

如果你拿到的是 \emph{别人已经跑完的} processed data（比如 zip 包），
而你不想重新下载 + 清洗（这部分约 5 分钟 + 300 MB 流量）：

```bash
# 解压到 data/processed/
unzip processed_bundle.zip -d data/processed/

# 跳过下载与清洗，直接校验 → 跑实验
make validate
make experiment
```

如果你只是想跑实验和出报告，**不需要重新下载 parquet**。
只要 `data/processed/` 下的 7 个 CSV 完整即可。

## 6. 常见坑

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| `make data` 提示下载失败 | 网络问题 | 手动从 NYC TLC 网站下载到 `data/raw/`（见 `data/raw/README_download.md`），再 `make data` |
| `make experiment` 中 Baltamatica 卡死 | 社区版 readtable 极慢 | 已用 `fopen+fread+sscanf` 替代，不应再发生 |
| `make experiment` 报 “csvread 缺一行” | Baltamatica `csvread` bug | 已绕开（用 `fopen+fread+sscanf`） |
| LP 与 greedy unmet 相同但 cost 差很多 | 这是 \emph{预期} 行为 | 看报告 §5 — LP 在同 unmet 水平下找全局最便宜路由 |
| 报告或 Beamer 编译失败 “Missing $” | csvsimple 与下划线 header 冲突 | 已用 `\begingroup\catcode`\_=12 ... \endgroup` 包住 |
| 中文字体缺失 | ctex 未安装 | `sudo tlmgr install ctex xecjk` |

## 7. 干净重置

```bash
make clean       # 只删 processed/, results/, LaTeX build
make distclean   # 上面 + raw/ + venv/
```

## 8. 校验你的复现是否正确

跑完 `make all` 后，对照以下数值（应当 bit-for-bit 一致，因为随机种子固定为 20260521）：

| 量 | 期望值 |
| --- | --- |
| panel 行数 | 109,250 |
| 50 zones 全连续 hour_index | 是 |
| historical_mean test MAE | ≈ 16.83 |
| ridge test MAE | ≈ 18.46 |
| LP @ $\lambda=20$ on last hour, real unmet | ≈ 77.7 |
| LP cost @ same | ≈ 3466.6 |
| MC mean unmet (LP) | ≈ 19.9 |
| MC q05 service rate (LP) | ≈ 0.9647 |

如有偏差，先检查：
1. 你的 NYC TLC parquet 是不是同一个月份 / 同一个 schema 版本。
2. cfg.rng_seed 是不是改过。
3. cfg.lambda_unmet, cfg.alpha_ridge 是不是改过。
