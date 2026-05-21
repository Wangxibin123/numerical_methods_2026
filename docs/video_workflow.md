# 视频工作流：Beamer → PNG → PowerPoint → MP4

> Beamer 适合做数学公式和最终 PDF；PowerPoint 适合录音 + 摄像头 + 导出视频。
> 我们把两者结合：北太天元 / Python 算 → Beamer 出 PDF → 转 PNG → PowerPoint 录音 → 导 MP4。

> 录制者：陈龙 = §1–§7，汤平之 = §8–§14。
> 王溪斌不录视频，可协助技术问题。

## 一键自动化

```bash
make video-prep
```

等价于：

```bash
cd slides
latexmk -xelatex main.tex          # → slides/main.pdf
mkdir -p slides/rendered
pdftoppm -png -r 220 slides/main.pdf slides/rendered/slide
```

结果：`slides/rendered/slide-01.png ... slide-14.png`。

## 第 1 步：Beamer 编译

```bash
make slides
# 或者：cd slides && latexmk -xelatex main.tex
```

预期输出 `slides/main.pdf` 14 页 16:9。

## 第 2 步：转高清 PNG

```bash
mkdir -p slides/rendered
pdftoppm -png -r 220 slides/main.pdf slides/rendered/slide
```

每页 \~2400×1350 像素，全屏铺到 PowerPoint 看不到模糊。

## 第 3 步：导入 PowerPoint

1. 打开 PowerPoint → New → Blank Presentation → 16:9。
2. 把 14 张 PNG 一次性拖进去，每张作为一个 slide 的全屏背景。
   - 推荐做法：每张图都缩放到 33.86 × 19.05 cm（全幅）。
   - 进阶：用一段 VBA / PowerPoint AppleScript 批量导入（耗时 10 s）。

## 第 4 步：录音 + 摄像头（讲稿见 `slides/narration.md`）

PowerPoint → "Slide Show" → "Record Slide Show" → "Record from Beginning"。

\textbf{录制约定（务必遵守）}：

- 每页画面出现后 \emph{停顿约 0.5 秒再开始讲话}。
- 翻页瞬间 \emph{不要说话} —— 否则会被切。
- 摄像头头像放 \emph{右下角}，不要遮公式和图表。
- 出错只重录该页（"Clear Recordings on Current Slide" → 重录）。
- 录制者按 `division_of_labor.md` 中的 Slide → 录制者对应表来分页。

## 第 5 步：导出 MP4

`File → Export → Create a Video`：

- 质量：Full HD (1080p)
- 选项：勾选 \textbf{"Use Recorded Timings and Narrations"}
- 选 “Create Video”，保存为 `video/final_video.mp4`。

> ⚠️ MP4 较大（\~200–500 MB），不入 git。上传到学校 LMS 与备份云盘后，
> 把分享链接写到 `video/README_video_link.md`。

## 第 6 步：交付确认

| 项 | 检查 |
| --- | --- |
| MP4 分辨率 | 1920 × 1080 |
| MP4 编码 | H.264 / AAC |
| 时长 | 7 – 10 分钟（讲稿合计） |
| 每页都有声音 | ✓ |
| 每位同学的头像都出现至少一次 | ✓ |
| LMS 提交链接可访问 | ✓ |
| `video/README_video_link.md` 已更新 | ✓ |

## 常见问题

- **Beamer 字体太小** → `\documentclass[aspectratio=169,12pt]{beamer}`。
- **中文不显示** → 确认 ctex 已安装；必须用 XeLaTeX（不能用 pdfLaTeX）。
- **PowerPoint 录音变声 / 杂音** → 麦克风采样率统一 48 kHz，关掉系统降噪。
- **导出 MP4 没有声音** → 检查 “Use Recorded Timings and Narrations” 勾选。
- **录到一半 PowerPoint 闪退** → 每录 2-3 页就保存一次；可分段录制后再合并。
- **Beamer 内容改了，PPT 跟着改吗？** → 不会自动同步。重新跑 `make video-prep`
  生成新 PNG，替换 PowerPoint 中对应 slide 背景，再重新录这几页。
  `slides/narration.md` 务必同步更新讲稿。
