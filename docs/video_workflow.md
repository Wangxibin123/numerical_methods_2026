# Beamer → PNG → PowerPoint → MP4 工作流

Beamer 适合做数学公式和最终 PDF；PowerPoint 适合录音 + 摄像头 + 导出视频。
两者结合：用 Beamer 输出高质量 slides，用 PowerPoint 录音/录像并导出 MP4。

## 步骤

### 1. 编译 Beamer

```bash
cd slides
latexmk -xelatex main.tex   # 产出 main.pdf
```

如果你的项目把入口文件改名为 `slides.tex`：

```bash
xelatex slides.tex
```

### 2. 每页转高清 PNG

```bash
mkdir -p slides/rendered
pdftoppm -png -r 220 slides/main.pdf slides/rendered/slide
```

得到 `slide-01.png, slide-02.png, ...`。

### 3. 导入 PowerPoint

1. 打开 PowerPoint，创建 “Widescreen 16:9 Blank Presentation”。
2. 每张 PNG 作为整页背景：
   - 推荐做法：插入 → 图片 → 选择全部 → 每张占满整页（拉伸到 33.86 × 19.05 cm）。
   - 或更稳：用一段 VBA / Python 脚本批量导入。

### 4. 录制 narration / 摄像头

PowerPoint → "Slide Show" → "Record Slide Show" → "Record from Beginning"。

约定：

- 每页开头停顿 0.5 秒再讲话。
- 翻页时不要说话。
- 摄像头头像 → 右下角，不遮挡公式和图表。
- 出错只重录对应 slide（"Clear Recordings on Current Slide" → 再录）。

### 5. 导出 MP4

`File → Export → Create a Video`：

- 质量：Full HD (1080p)
- 选项：Use Recorded Timings and Narrations
- 选 “Create Video”，保存为 `video/final_video.mp4`

> ⚠️ MP4 较大，不入 git。最终视频上传到学校或公共云盘后，把分享链接写到
> `video/README_video_link.md`。

## 常见问题

- **Beamer 字体太小**：在 `main.tex` 中改 `\documentclass[aspectratio=169,12pt]{beamer}`。
- **中文不显示**：确认安装 ctex；XeLaTeX 必需（PdfLaTeX 不支持）。
- **PowerPoint 录音变声**：检查麦克风采样率，统一 48 kHz。
- **导出 MP4 没有声音**：检查 “Use Recorded Timings and Narrations” 是否被勾选。
