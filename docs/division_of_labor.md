# 成员分工

> 本项目 3 人组分工。**王溪斌不参与录制视频环节**，
> 由其负责的核心代码 / 数据 / LP / 优化 / 文档相关任务由其牵头。
> 视频录制由陈龙与汤平之负责。

| 姓名 | 学院 / 年级 | 主要责任 | 录视频 |
| --- | --- | --- | :---: |
| **王溪斌** | 22 光华 | 项目主架构师；端到端流水线（数据 ↔ 北太天元 ↔ 图渲染）；LP 公式与代码实现；Monte Carlo & λ 敏感性；所有 `.m` 代码 + 测试；数据完整性 11 项校验脚本；报告主体撰写；Makefile 与复现说明 | ❌ |
| **陈龙** | 23 信科 | 数据 pipeline：NYC TLC 下载 / 清洗 / zone-hour 聚合 / 特征工程 / cost 矩阵；OD median 兜底策略；附录 A/B/G 起草；视频 P1-P7 录制 | ✅ |
| **汤平之** | 23 元培 | 报告与 Beamer 排版（含中文 ctex 字体调试）；图表整理；预测精度对比表；附录 C/F/J/L/M 起草；视频 P8-P14 录制 + PPT 录音合成 + MP4 导出 | ✅ |

## 详细任务清单

### 王溪斌（22 光华，**不录视频**）

主架构 + 主求解 + 文档骨干。

#### 代码与数学（核心）

| 任务 | 文件 | 说明 |
| --- | --- | --- |
| 全局参数管理 | `code/beita/config_project.m` + `code/python/_config.py` | λ、α、Monte Carlo 次数、随机种子等 |
| Baltamatica 兼容快速 CSV 读 | `code/beita/load_processed_data.m` | `fopen+fread+sscanf`（社区版 `csvread` 损坏的 workaround） |
| Train/Val/Test split 校验 | `code/beita/split_train_test.m` | 与 cfg 占比对照，差异 > 5% 报警 |
| 历史均值预测器 | `code/beita/predict_historical_mean.m` | 三维 cube (zone × wd × hod) 高效查表 |
| Ridge 回归（闭式） | `code/beita/predict_ridge.m` | `(X'X + αI)^{-1} X'y`，列标准化，截断到 0 |
| LP 调度求解 | `code/beita/solve_rebalance_lp.m` | column-major 变量序，`linprog` |
| Greedy baseline | `code/beita/greedy_rebalance.m` | 最近邻贪心 |
| 调度真实评估 | `code/beita/evaluate_dispatch.m` | 用 `P_true_next` 计算真实 unmet / cost / 服务率 |
| Monte Carlo 稳健性 | `code/beita/monte_carlo_robustness.m` | 200 次 Poisson 扰动；自实现 `quantile_safe` 与 Knuth Poisson |
| 数据导出（给 Python 渲图用） | `code/beita/export_figure_data.m` | 5 张图源 CSV |
| run_all 主流水线 | `code/beita/run_all.m` | 一键 12 步 |
| 数据完整性校验 | `code/python/06_validate.py` | 11 项断言（列对齐、连续性、cost matrix sanity、test_hours 落在 test 切分内等） |
| 图像渲染 | `code/python/07_render_figures.py` | matplotlib 纯渲图，不做计算 |
| 单元测试 | `code/beita/tests/test_*.m` | 3 个 LP 算例 + run\_all\_tests |

#### 文档骨干

- `README.md` 顶层导引
- `docs/reproduce.md` 复现说明
- `docs/limitations.md` 局限
- `docs/beita_usage_notes.md` 北太天元 6 项兼容性发现
- `Makefile`（一键 data / experiment / report / slides / video-prep / tests）
- 报告 §1 - §6 主体 + 附录 D/E/H/I/K

### 陈龙（23 信科，录视频 P1 - P7）

数据 pipeline 主程。

#### 代码任务

| 任务 | 文件 |
| --- | --- |
| TLC 月度 parquet 下载（带进度条 + 断点） | `code/python/01_download_tlc.py` |
| 清洗与合并 | `code/python/02_preprocess_trips.py` |
| zone-hour 完整网格 + 特征工程 | `code/python/03_build_features.py` |
| 测试小时选取（找首个 24-小时连续 day） | `code/python/03_build_features.py` `_select_test_hours` |
| Cost matrix OD median 兜底 | `code/python/04_build_cost_matrix.py` |
| Optional 地图渲染 | `code/python/05_optional_maps.py` |
| 端到端 orchestrator | `code/python/run_preprocess.py` |

#### 文档与报告任务

- `data/README_data.md` 完整字段说明
- `data/raw/README_download.md` 手动下载指南
- 报告附录 A（数据字段说明）
- 报告附录 B（清洗规则与样本数变化）
- 报告附录 G（Python 预处理脚本说明）

#### 视频任务（P1 - P7）

- 录 Beamer 1 - 7 页（详见 `slides/narration.md`）
- 参与 12 - 14 页致谢部分合录

### 汤平之（23 元培，录视频 P8 - P14 + 后期）

报告 / Beamer / 视频后期主程。

#### 报告与 Beamer 任务

- `report/report.tex` 排版与图表对齐（含 ctex 配置）
- `slides/main.tex` 14 页 Beamer 模板（含每页讲稿编号锚点）
- 表 1（清洗摘要展示）、表 2（预测对比）、表 3（调度对比）排版
- 调整 figure 大小与说明
- 报告附录 C（特征工程表）
- 报告附录 F（北太天元核心代码索引）
- 报告附录 J（AI 工具使用说明）
- 报告附录 L（成员分工）
- 报告附录 M（复现说明）

#### 文档任务

- `docs/ai_usage.md`
- `docs/division_of_labor.md`（本文件，与王溪斌一起维护）
- `docs/video_workflow.md` 视频工作流
- `slides/narration.md` 14 页讲稿（与王溪斌一起对照内容更新）

#### 视频任务（P8 - P14 + 后期）

- 录 Beamer 8 - 14 页（详见 `slides/narration.md`）
- 把 7 张 PNG (P1-P7) + 自己录的 PNG 合成入 PowerPoint
- 添加每位的摄像头头像（右下角）
- 设置 0.5 s 启动空白 + 翻页静音
- PowerPoint 导出 1080p MP4 到 `video/final_video.mp4`
- 上传到学校 LMS + 备份云盘
- 更新 `video/README_video_link.md`

## Slide → 录制者对应表

| Slide # | 内容 | 录制者 | 讲稿来源 |
| :---: | --- | --- | --- |
| 1 | 封面 | 陈龙 | `slides/narration.md` §1 |
| 2 | 现实问题 | 陈龙 | §2 |
| 3 | 数据来源 | 陈龙 | §3 |
| 4 | Zone-Hour 面板 | 陈龙 | §4 |
| 5 | 需求预测两个模型 | 陈龙 | §5 |
| 6 | 供需缺口定义 | 陈龙 | §6 |
| 7 | LP 再平衡模型 | 陈龙 | §7 |
| 8 | Baselines | 汤平之 | §8 |
| 9 | 北太天元实现流程 | 汤平之 | §9 |
| 10 | 实验结果 - 调度对比 | 汤平之 | §10 |
| 11 | 实验结果 - top flows | 汤平之 | §11 |
| 12 | Monte Carlo | 汤平之 | §12 |
| 13 | 结论与局限 | 汤平之 | §13 |
| 14 | 致谢 | 汤平之 | §14 |

## 协作约定

- **代码** 通过 git PR；提交格式：`type(scope): subject` (`feat`/`fix`/`docs`/`chore`/`refactor`)。
- **数据文件** 不入 git（`.gitignore` 已配置），但 README 和 reproduce.md 必须保证别人能跑出来。
- **结果表与图** 入 git（`results/`），方便他人审阅而不必跑全流程。
- **视频文件** 不入 git，链接放 `video/README_video_link.md`。
- **新代码** 提交前必须本地通过 `make tests`。
- **大变动** 在 group chat 同步，避免冲突。

## 紧急联系

如某一位临时缺席：
- 数据 pipeline 由陈龙顶替（备份：王溪斌）
- 报告 / Beamer 排版由汤平之顶替（备份：王溪斌）
- 视频录制由陈龙 + 汤平之分担（王溪斌不录但可以协助技术问题）
