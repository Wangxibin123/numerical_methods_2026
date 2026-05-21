# 北太天元 (Baltamatica) 使用笔记

> 本文件汇总在本项目中使用 Baltamatica 2025 社区版时遇到的兼容性问题、踩坑点和经验。
> 课程要求必须包含此部分。

## 环境

- **Baltamatica 2025 社区版** （macOS arm64，已实测全流程通过）
- 含 `linprog` （社区版自带，无需 Optimization Toolbox 激活）
- macOS 14+ / Apple Silicon

## 通过命令行调用

我们用 stdin 把脚本喂给 Baltamatica，避免手动打开 GUI：

```bash
printf "cd '...';\nrun_all;\nexit\n" \
  | /Applications/Baltamatica.app/Contents/MacOS/baltamaticaC.sh
```

`make experiment` 已经封好了这一步。

## 6 项兼容性发现与 workaround

### 1. `csvread` 在多行 + 尾部换行时丢行并数值错乱

**症状**：

```
% file: 3 行 3 列，正确值 1..9
M = csvread('test.csv');
% 返回 2x3 矩阵，值约等于 1e-323（垃圾值）
```

**Workaround**：用 `fopen + fread + sscanf` 自实现快速 CSV 读：

```
function M = read_numeric_csv(path, n_cols)
    fid = fopen(path, 'r');
    buf = fread(fid, '*char')';
    fclose(fid);
    buf = strrep(buf, ',', ' ');
    nums = sscanf(buf, '%f');
    M = reshape(nums, n_cols, [])';
end
```

实现见 [code/beita/load_processed_data.m](../code/beita/load_processed_data.m)。
比 `readtable` 在 100k 行 CSV 上快 \~30 倍。

### 2. `error(...)` 不接受 printf 多参数

**症状**：

```
error('shape %dx%d', K, K);   % Baltamatica: "输入参数过多"
```

**Workaround**：先 sprintf 再 error：

```
error(sprintf('shape %dx%d', K, K));
```

我们用一个 Python regex 一次性把全仓库 `error(...)` 都包了 sprintf。

### 3. `onCleanup` 不可用

**症状**：

```
cleanup = onCleanup(@() fclose(fid));   % "未定义"
```

**Workaround**：手动 try/catch + fclose：

```
try
    ... do work ...
    fclose(fid);
catch err
    fclose(fid);
    rethrow(err);
end
```

### 4. `containers.Map` 不可用（无 Java）

**症状**：`containers.Map(...)` "未定义的变量或函数"。

**Workaround**：用 dense 数组索引。对 `(zone, weekday, hour_of_day)` 三元组，
我们把 zone 映射到 1..K 后用 `[K, 7, 24]` 三维 cube。比 hashmap 还快。

实现见 [code/beita/predict_historical_mean.m](../code/beita/predict_historical_mean.m)。

### 5. 没有 `figure / plot / print / close / saveas`（无图形子系统）

**Workaround**：把所有图源数据导出为 CSV
（[code/beita/export_figure_data.m](../code/beita/export_figure_data.m)），
再用 Python matplotlib 渲染
（[code/python/07_render_figures.py](../code/python/07_render_figures.py)）。

\textbf{优点}：这个分工反而更清晰 ——
\emph{所有数学和优化都在北太天元里}，Python 只做像素渲染。
完全符合作业要求 “北太天元做主求解”。

### 6. 测试脚本中的 `clear` 会清掉外层 run_all_tests 的计数器

**症状**：

```
% run_all_tests.m:
passed = 0; failed = 0;
for k = 1:numel(tests)
    run(fullfile(here, [tests{k} '.m']));   % inner script 内有 clear
    passed = passed + 1;                    % "未定义"
end
```

**原因**：`run()` 在 \emph{调用者作用域} 执行；inner script 里的 `clear` 会把
`passed`/`failed` 一并清掉。

**Workaround**：去掉 inner test 里的 `clear`。

## 其他兼容性观察

| 函数 | 状态 | 说明 |
| --- | --- | --- |
| `linprog` | ✅ | 全功能可用 |
| `optimset` | ✅ | 可用，社区版接受 'Display'='off' |
| `optimoptions` | ✅ | 居然也有 |
| `readtable` | ✅ | 可用但慢；适合小 CSV |
| `quantile` | ✅ | 可用 |
| `rng(seed, 'twister')` | ✅ | 可用 |
| `mkdir`, `fopen`, `fread`, `fwrite`, `fprintf`, `sprintf`, `sscanf` | ✅ | 全可用 |
| `arrayfun`, `cellfun`, `containers.Map` | ⚠️ | arrayfun/cellfun 可用，Map 不可用 |
| `try/catch`, `rethrow` | ✅ | 可用 |
| `csvread`, `csvwrite` | ❌ | csvread 数据错乱，csvwrite 不存在 |
| `figure`, `plot`, `print`, `saveas`, `close`, `bar`, `imagesc` | ❌ | 社区版无图形子系统 |

## 性能小结（109k 行面板）

| 操作 | 北太天元社区版 |
| --- | --- |
| `readtable('panel.csv')` | > 60 s（不可接受） |
| `fopen+fread+sscanf`（我们用的方式） | ~1.5 s |
| `linprog` (1700 vars) | ~0.1 s |
| 整个 `run_all`（24 hr + MC×200） | ~30 s |

## 给课程组的建议

- `csvread` 的尾部换行 + 数值错乱是项目最大障碍，修复后会大幅提升易用性。
- 若能补全 `figure/plot` 子集（哪怕是非交互的 PNG 输出），社区版可用度会显著上升。
- `error(fmt, args)` 的 printf 多参数支持是简单改动，对教学项目很有帮助。
- `containers.Map` 与 `onCleanup` 这类常用 helper 的支持也有助于直接复用通用脚本。
