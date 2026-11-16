# AGENTS.md — SCG LyricClips（给 Codex 的工作规则）
- 权威规格是 `DEV_SPEC.md`。按 §15 的 ticket 顺序做，**一张 ticket 一个 PR**，PR 标题以 ticket ID 开头（例如 `T2-3: NWLyricAligner`）。
- 先写测试再写实现。PR 描述必须写明：对应的 ticket、验收标准的逐条勾选、没做的部分、需要 Umi 在 Mac 或真机上验证的步骤。
- 你的环境大概率是 Linux：纯 Swift 的 target（`LCCore` `LCText` `LCAlign` `LCTiming` `LCTemplates` `LCSubtitles` `LCModelStore`）必须只依赖 Foundation 和 swift-crypto，`swift test` 必须能通过。Apple 专属代码用 `#if canImport(CoreML)` 或 `#if canImport(AVFoundation)` 隔离，并且不要声称在 Linux 上验证过它们。
- 禁止：FFmpeg、x264 和任何 GPL/AGPL 依赖；analytics、广告、崩溃上报 SDK；上传用户音频或歌词的任何代码；在 Release 配置下链接 HTDemucs（它的权重只限研究用途，见 DEV_SPEC §9）。
- 新增任何依赖或模型，都要同时更新 `docs/THIRD_PARTY_NOTICES.md` 和 `docs/MODEL_PROVENANCE.md`。许可证不明的，标 `provenance: "unverified"`，并在 PR 里提出来。
- 测试数据只用 `Tests/Fixtures` 里的合成数据或 SCG Audio 自有曲目，不能提交任何第三方版权歌曲或歌词。
- 时间统一用秒（Double），以原曲 0 点为基准；导出时才换成相对片段起点的时间。
- 代码风格：Swift 6 strict concurrency，公开 API 写 `///` 文档注释，用 SwiftFormat 和 SwiftLint 的默认配置；不要做和 ticket 无关的重构。
- 不要合并 PR，不要改 `main` 分支保护设置，不要创建 release 或 tag。规格有歧义时，在 PR 里提问，不要自行扩展需求。
