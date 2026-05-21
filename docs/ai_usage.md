# AI 工具使用说明

按课程要求，本附录公开本项目中 AI 工具的使用范围。

## 一句话总结

本项目的 \emph{所有数学建模、北太天元代码、清洗阈值、$\lambda$ 选择、实验结果与解读}
均由我们三人讨论决定。AI 工具仅在以下边角任务上做过模板辅助：

- 部分 Python 脚手架的初稿（团队对照 NYC TLC 文档手工修正）。
- LaTeX 报告与 Beamer 的样板格式（包括 ctex 字体配置与 booktabs 表格语法）。
- Markdown 文档（README、reproduce、video\_workflow）的版式参考。
- 调试 Baltamatica 2025 社区版兼容性时的语法查询。

## 不涉及 AI 的核心环节

- NYC TLC 数据范围（2024-Q1）的选择 — 团队讨论权衡。
- 清洗规则（trip\_distance、duration、fare 阈值） — 团队基于数据直方图敲定。
- 北太天元 LP 矩阵的 column-major 排列方案 — 团队手算 2×2 算例并通过 3 个单元测试验证。
- $\lambda = 20$ 的选择 — 基于 \verb|sensitivity_lambda.csv| 拐点分析决定。
- 历史均值 vs Ridge 的对比与结论解读 — 团队讨论后写入报告。
- Monte Carlo 200 次扰动设置、Poisson vs bootstrap 的取舍 — 团队讨论。
- 实验结果（“LP 同 unmet 水平下空驶成本低 2--5 倍”等）的图表解读 — 团队完成。
- 视频录制 / PPT 整合 / 字幕 / 摄像头叠加 — 全部人工。

## 责任声明

所有数学公式、北太天元 \verb|.m| 代码、最终结论与报告正文由团队成员审阅并负责。
报告与展示中的所有结果均可重现，复现命令见 \verb|docs/reproduce.md|。

我们对所有由模板辅助生成的代码做了以下硬性检查：

- LP 求解结果用独立的 SciPy `linprog` 镜像在 3 个小算例上完全对齐（差异 $< 10^{-6}$），
  详见 \verb|code/beita/tests/|。
- 数据完整性 11 项断言全绿（详见 \verb|code/python/06_validate.py|）。
- 北太天元端的全部 \verb|.m| 都做了至少一次端到端跑通验证（24 个测试小时全跑过）。
- 报告中所有数字均来自本仓库 \verb|results/tables/| 的真实输出，无人工填写。
