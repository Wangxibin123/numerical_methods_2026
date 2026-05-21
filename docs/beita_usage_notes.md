# 北太天元使用笔记 / 问题与建议

> 本文件汇总在本项目中使用北太天元（Baltam）时遇到的兼容性问题、踩坑点和经验。
> 课程要求必须包含此部分。

## 环境

- 北太天元桌面版（任意 2023+ 发行版）
- 含 Optimization 工具（提供 `linprog`）
- macOS / Windows / Linux 均经过最小测试

## 已知差异 / 注意点

### 1. `csvread` vs `readtable`

北太天元的 `csvread` 默认不接受 header / 非数字单元，建议：

- 数值矩阵 → 用 `csvread`（推荐使用我们提供的 `panel_numeric_noheader.csv`）。
- 含字符串列 → 用 `readtable`，再 `T.column_name` 访问。

我们在 `load_processed_data.m` 中做了 try-catch fallback。

### 2. `optimoptions` 不一定可用

```matlab
opts = optimoptions('linprog', 'Display', 'off');
```

旧版可能没有 `optimoptions`，请用：

```matlab
opts = optimset('Display', 'off');
```

`solve_rebalance_lp.m` 已内置自动 fallback。

### 3. `containers.Map` 可用，但 `dictionary`（R2022b+）不一定

我们统一使用 `containers.Map`。

### 4. `quantile` / `boxplot` 可能受 Statistics Toolbox 限制

- 不依赖 `quantile`：自实现 `quantile_safe` 在 `monte_carlo_robustness.m`。
- 不依赖 `boxplot`：自实现 `simple_box` 在 `make_core_figures.m`。

### 5. 中文路径

避免脚本路径含中文 / 空格。本仓库默认路径 `Desktop/数值分析大作业/` 含中文，
若发现 `fileparts` 返回异常，可把仓库克隆到无中文的路径再跑。

### 6. `rng(seed, 'twister')` 行为

我们假设北太天元和 MATLAB 一致地接受 `rng(seed, 'twister')`。
如果报错，可换成 `rand('twister', seed)`。

### 7. `print(f, out, '-dpng', '-r150')` 兼容

如果某些版本不支持 `print` 写 PNG，改用：

```matlab
saveas(f, out, 'png');
```

## 建议（给课程组）

- `csvread` 默认行为如能与 MATLAB 完全一致（包括 header 自动跳过），会节省大量
  fallback 代码。
- `linprog` 的 `Algorithm` 参数命名建议与 MATLAB 对齐（`'dual-simplex'`,
  `'interior-point'`），方便课程脚本跨工具运行。
- 错误信息中保留 `caller stack` 比较有帮助，方便调试 nested 函数。
