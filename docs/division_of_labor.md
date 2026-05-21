# 成员分工

> 第一组按 **Modeling / Data / Presentation** 三个 lead 分工，工作量大致均衡。
> **王溪斌不录视频**，他承担更重的核心建模与代码工作以做补偿；
> 视频录制由陈龙与汤平之均分（陈龙 P1-P8 = 8 帧，汤平之 P9-P15 = 7 帧 + 后期）。

| 姓名 | 学院 / 年级 | 角色 | 录视频 |
| --- | --- | --- | :---: |
| **王溪斌** | 22 光华 | Modeling Lead — 数学建模 / LP / Ridge / 北太天元核心代码 | ❌ |
| **陈龙** | 23 信科 | Data Lead — Python 数据 pipeline / 数据校验 / MC 设计 / 前半视频 | ✅ |
| **汤平之** | 23 元培 | Presentation Lead — 报告 & Beamer 排版 / 图渲染 / PPTX / 后半视频 + 后期 | ✅ |

## 各人详细任务清单

### 王溪斌（22 光华，Modeling Lead）

**核心建模 + 北太天元代码**

| 任务 | 文件 |
| --- | --- |
| LP 调度求解（column-major + linprog） | `code/beita/solve_rebalance_lp.m` |
| Ridge 回归（闭式 $\hat\beta=(X^\top X+\alpha I)^{-1}X^\top y$） | `code/beita/predict_ridge.m` |
| 历史均值预测器（zone × wd × hod 三维 cube） | `code/beita/predict_historical_mean.m` |
| Greedy 最近邻 baseline | `code/beita/greedy_rebalance.m` |
| 单小时 S/D/Q/P_true 构造 | `code/beita/build_rebalance_vectors.m` |
| 调度真实评估（用 $P^{true}_{t+1}$） | `code/beita/evaluate_dispatch.m` |
| Baltamatica 兼容快速 CSV 读 | `code/beita/load_processed_data.m` |
| Train/Val/Test split 校验 | `code/beita/split_train_test.m` |
| run_all 主流水线（一键 12 步） | `code/beita/run_all.m` |
| 全局参数（α / λ / MC 次数 / 种子） | `code/beita/config_project.m` + `code/python/_config.py` |
| 3 个 LP 手算单元测试 | `code/beita/tests/test_*.m` + `run_all_tests.m` |
| λ 经济推导（NYC TLC 费率 + 司机成本 → [20,42]） | 报告 §3 + Beamer §8 数据 |

**报告与文档**

- 报告 §1 背景、§3 数学模型、§4 算法实现、§6 结论与局限
- 报告附录 D（数学）/ E（LP column-major 矩阵）/ I（λ sensitivity）/ K（北太兼容性）
- `README.md` 顶层导引
- `docs/reproduce.md` 协作者复现指南
- `docs/limitations.md` 项目局限
- `docs/beita_usage_notes.md` 北太天元 6 项兼容性发现
- `Makefile` 8 个 target（make all / data / experiment / report / slides / pptx / tests / clean）

**不录视频**（但可协助技术问题）。

---

### 陈龙（23 信科，Data Lead，录视频 P1-P8）

**Python 数据 pipeline + 数据校验 + MC 实验设计**

| 任务 | 文件 |
| --- | --- |
| TLC 月度 parquet 下载（进度条 + 断点） | `code/python/01_download_tlc.py` |
| 清洗与多月合并（8 条规则） | `code/python/02_preprocess_trips.py` |
| zone-hour 完整网格 + 17 列特征 | `code/python/03_build_features.py` |
| 测试小时选取（找首个 24h 连续 day） | `code/python/03_build_features.py` `_select_test_hours` |
| Cost matrix OD median + 兜底策略 | `code/python/04_build_cost_matrix.py` |
| 端到端 Python orchestrator | `code/python/run_preprocess.py` |
| 可选地图渲染 | `code/python/05_optional_maps.py` |
| 数据完整性 11 项断言（NaN / 连续性 / cost sanity / split 占比 / 存活率） | `code/python/06_validate.py` |
| Monte Carlo 稳健性（200 次 Poisson + 自实现分位数 + Knuth Poisson 采样） | `code/beita/monte_carlo_robustness.m` |
| TLC zone 264/265 排除（数据陷阱发现） | `03_build_features.py` `_EXCLUDED_ZONE_IDS` |

**报告与文档**

- 报告 §2 数据与特征、§5 实验结果（数据部分）
- 报告附录 A（数据字段）/ B（清洗规则与样本数变化）/ G（Python 脚本）/ H（蒙特卡洛参数）
- `data/README_data.md` 完整字段说明
- `data/raw/README_download.md` 手动下载指南

**视频任务（P1-P8，8 帧）**

- 录 Beamer 1-8 页（含 §8 λ 经济学依据）
- 讲稿见 `slides/narration.md` §1-§8（合计约 690 秒 ≈ 11.5 min）

---

### 汤平之（23 元培，Presentation Lead，录视频 P9-P15 + 后期）

**图渲染 + 排版 + 报告 & Beamer**

| 任务 | 文件 |
| --- | --- |
| 6 张 PNG 图像渲染（matplotlib，纯渲图无计算） | `code/python/07_render_figures.py` |
| Beamer PNG → PPTX 自动拼装 + 讲稿同步进备注 | `code/python/08_build_pptx.py` |
| 北太天元图源 CSV 导出（5 张图数据） | `code/beita/export_figure_data.m` |
| 报告排版（12pt + 1.5 行距 + ctex 字体调试） | `report/report.tex` |
| Beamer 排版（15 帧 16:9 + Madrid 主题） | `slides/main.tex` |
| 图表对齐 + caption 编辑 + 表格美化（4 张表） | 同上 |
| 报告 §5 实验结果撰写（结果解读） | `report/report.tex` |
| 报告附录 C（特征工程表）/ F（北太代码索引）/ J（AI 使用）/ L（分工）/ M（复现） | 同上 |
| 中文讲稿（15 帧 ≈ 21 min） | `slides/narration.md` |

**文档**

- `docs/ai_usage.md` AI 工具使用声明
- `docs/division_of_labor.md`（本文件）
- `docs/video_workflow.md` 视频工作流
- `slides/narration.md` 讲稿（与王溪斌一起对照内容更新）

**视频任务（P9-P15 + 后期）**

- 录 Beamer 9-15 页（讲稿 `slides/narration.md` §9-§15，合计约 570 秒 ≈ 9.5 min）
- 在 PowerPoint 中合成陈龙录的 P1-P8 + 自己录的 P9-P15
- 添加每位的摄像头头像（右下角，不遮公式）
- 设置 0.5 s 启动空白 + 翻页静音
- PowerPoint 导出 1080p MP4 到 `video/final_video.mp4`
- 上传到学校 LMS + 备份云盘
- 更新 `video/README_video_link.md`

---

## 工作量大致对照

| 维度 | 王溪斌 | 陈龙 | 汤平之 |
| --- | :---: | :---: | :---: |
| 代码文件数 | 11 (.m + config) | 8 (Python) + 1 (.m) | 3 (Python + .m) + 排版 |
| 报告章节 | §1 / §3 / §4 / §6 | §2 / §5 (数据) | §5 (解读) + 排版 |
| 报告附录 | D / E / I / K (4) | A / B / G / H (4) | C / F / J / L / M (5) |
| 文档 | 4 (README / reproduce / limitations / beita) | 2 (data README) | 4 (ai / division / video / narration) |
| 视频 | ❌ | 录 8 帧 (≈11.5 min) | 录 7 帧 (≈9.5 min) + 后期 |

**平衡说明**：王溪斌不录视频，但承担最重的核心算法（LP / Ridge / 评估 / 主流水线）；
陈龙和汤平之的视频量大致相当（11.5 min vs 9.5 min + 后期合成 + MP4 导出 + 上传），
非视频工作量也基本相当。

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
| 8 | λ 的经济学依据 & 敏感性 | 陈龙 | §8 |
| 9 | Baselines | 汤平之 | §9 |
| 10 | 北太天元实现流程 | 汤平之 | §10 |
| 11 | 实验结果 - 调度对比 | 汤平之 | §11 |
| 12 | 实验结果 - top flows | 汤平之 | §12 |
| 13 | Monte Carlo | 汤平之 | §13 |
| 14 | 结论与局限 | 汤平之 | §14 |
| 15 | 致谢 | 汤平之 | §15 |

## 协作约定

- **代码** 通过 git PR；提交格式：`type(scope): subject` (`feat`/`fix`/`docs`/`chore`/`refactor`)。
- **数据文件** 原始 parquet 不入 git（`.gitignore` 已配置），processed CSV 入 git 便于协作者直接跑实验。
- **结果表与图** 入 git（`results/`），方便他人审阅而不必跑全流程。
- **视频文件** 不入 git，链接放 `video/README_video_link.md`。
- **新代码** 提交前必须本地通过 `make tests`。
- **大变动** 在 group chat 同步，避免冲突。

## 紧急联系

如某一位临时缺席：
- 数据 pipeline 由陈龙顶替（备份：王溪斌）
- 报告 / Beamer 排版由汤平之顶替（备份：王溪斌）
- 视频录制由陈龙 + 汤平之分担（王溪斌不录但可以协助技术问题）
