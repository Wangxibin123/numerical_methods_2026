# 成员分工

> 模板，按实际成员人数与姓名调整后入仓。

## 3 人组（默认）

| 成员 | 主要责任 |
| --- | --- |
| **A — 数据与预处理** | NYC TLC 数据下载 / Python 清洗 / zone-hour 面板 / 成本矩阵 / 数据附录 / 复现说明数据部分 |
| **B — 模型与北太天元** | historical mean / ridge / LP linprog / greedy baseline / Monte Carlo / 结果表 / λ 敏感性 / 单元测试 |
| **C — 报告与展示** | LaTeX report 排版 / Beamer slides / 图表整理 / PPT 录音聚合 / 视频导出 |

## 4 人组（可选扩展）

新增：

| 成员 | 主要责任 |
| --- | --- |
| **D — 实验审计与复现** | λ 敏感性进一步分析 / 单元测试扩展 / README / AI usage / 北太天元使用反馈 / 最终压缩包检查 |

## Slide 区间分配（示例，需按最终页数调整）

`slides/main.tex` 默认 12 帧 + 1 标题 + 1 致谢。建议：

| Slides | 负责录音 |
| --- | --- |
| 1–4 标题 / 现实问题 / 数据 / 面板 | A |
| 5–7 预测 / 缺口 / LP | B |
| 8–10 北太天元流程 / 实验结果 / 结果之二 | C |
| 11–12 Monte Carlo / 结论 | D（或全员） |
| 致谢 | 全员合录 |

## 协作约定

- 所有代码改动通过 PR / commit message 解释。
- 提交格式：`type(scope): subject` — `feat`, `fix`, `docs`, `chore`, `refactor`。
- 数据文件不提交 git（已在 `.gitignore`）。
- 结果表与图允许提交以便回顾，但视频不提交（链接放 `video/README_video_link.md`）。
