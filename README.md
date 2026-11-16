# SCG LyricClips — 规格与工程导航

当前仓库已完成 **v0.2 开发规格与工作规则整合**，尚未开始 App 代码实现。

## 核心权威文档
- **[DEV_SPEC.md](DEV_SPEC.md)（v0.2 现行权威规格）**：已整合 Codex 审阅发现的 14 项契约修正与 Gemini 复核的轻量化工程裁剪（如 `whisper.cpp` DTW 显式关闭 `flash_attn`、外置 `vDSP` STFT/iSTFT + 窗权重归一化 Overlap-Add、UTF-16 文本区间映射、重复副歌零代价平局检测、字幕先求交再平移、内置 `ApprovedModelAllowlist` 安全门禁、确定性文件缓存替代复杂状态机等）。
- **[AGENTS.md](AGENTS.md)（v0.2 现行工作规则）**：定义了云端 Linux（7 个纯 Swift 核心模块 TDD）与本地 Mac Studio + iPhone（Xcode 构建、Apple 框架集成、Phase 0 真机跑分）的协同开发守则与红线。

## 历史审阅与验证归档（2026-11-17）
- [完整审阅反馈](docs/reviews/2026-11-17/REVIEW.md)：Codex 对 v0.1 规格的 14 项问题、上游源码证据、建议和验收条件。
- [规格修订建议初稿](docs/reviews/2026-11-17/DEV_SPEC_REVISIONS.md) 与 [工作规则修订建议初稿](docs/reviews/2026-11-17/AGENTS_PROPOSED.md)：审阅阶段的建议原稿（核心内容已裁剪合入根目录 `DEV_SPEC.md` 与 `AGENTS.md`）。
- [合成审阅检查脚本](docs/reviews/2026-11-17/review_checks.py) 及 [运行结果](docs/reviews/2026-11-17/review-check-results.json)：针对 Hann 窗未归一化纹波、零代价副歌平局、缓存 Key 遗漏、字幕边界裁剪与 DTW 时间偏移的数学反例验证。

## 三端协同开发分工
1. **云端（Linux）**：负责 `Packages/LyricClipsKit` 下 7 个纯 Swift 模块（`LCCore`、`LCText`、`LCAlign`、`LCTiming`、`LCTemplates`、`LCSubtitles`、`LCModelStore`）的实现与 `swift test` 单元测试。
2. **Mac Studio + Xcode**：负责 iOS 工程构建、签名、模拟器测试、Apple 专属模块（`LCAppleText`、`LCAudio`、`LCSeparation`、`LCTranscription`、`LCRender`、`LCExport`、`LCPipeline`、`LCUI`）集成，以及 Phase 0 Step A 本地快速筛选。
3. **iPhone 真机（iPhone 12 及新机型）**：负责 Phase 0 Step B 真机推理耗时、Instruments Physical Footprint 峰值内存、发热状态与 Tap-to-sync 手感验收。
