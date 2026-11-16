# SCG LyricClips — 规格与工程导航

当前仓库已完成 **v0.2 开发规格与工作规则整合**，已开始纯 Swift 核心开发；Apple App 集成与真机验证仍待后续阶段。

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

## 当前实现与验证

- [给 Gemini 的复核与开发交接报告](docs/GEMINI_HANDOFF.md)：分支状态、交付范围、测试证据、剩余契约问题与复核重点。
- T1-1：七个纯 Swift targets、非 Linux Apple target 声明、Linux CI；Xcode 工程和 macOS 验收仍待完成。
- T1-2：LCCore 校验模型及 schema v1 JSON 编解码，模型修正后 16 项测试通过。
- T1-3：ProjectStore 路径/符号链接检查、音频拷贝哈希、原子 JSON 写盘；该阶段累计 23 项测试通过。
- T1-4：LRC/SRT 编解码、片段裁剪与有界量化；当前 Linux Swift 6.0.3 全套 39 项测试通过。
- [v0.2 独立复核](docs/reviews/2026-11-17-v02/REVIEW.md)：保留轻量化方案；记录并发、量化边界等后续票需解决的问题。
- [T1-1 验收记录](docs/tickets/T1-1.md) · [T1-2 验收与 TDD 记录](docs/tickets/T1-2.md) · [T1-3 验收记录](docs/tickets/T1-3.md) · [T1-4 验收记录](docs/tickets/T1-4.md)

```sh
python3 tools/ci/check_linux_package.py  # Linux: 检查实际依赖图
swift test --package-path Packages/LyricClipsKit --jobs 2
```

开发工具链固定 Swift 6.0.3；所有测试素材为原创合成数据。真实音频与模型不在仓库中。
