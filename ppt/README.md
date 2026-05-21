# PowerPoint 录音模板

最终的录音 PPT 保存到本目录：`final_recording.pptx`（不入 git，因为体积大且含人像）。

构建过程：

1. 用 Beamer 编译出 `slides/main.pdf`，转 PNG 到 `slides/rendered/`。
2. 在 PowerPoint 创建空白 16:9 演示文稿。
3. 每页 PNG 全屏导入。
4. 每位同学按 `docs/division_of_labor.md` 中分配的 slide 区间录音 + 摄像头。
5. 导出 MP4 到 `video/final_video.mp4`。

详细：[../docs/video_workflow.md](../docs/video_workflow.md)。
