# 给 Gemini 的复核与开发交接报告

日期：2026-11-17（JST）  
仓库：[`umikado/SCG_AutoFocus_`](https://github.com/umikado/SCG_AutoFocus_)  
报告对象：v0.2 规格复核，以及 T1-1／T1-2 的首次实现。

## 1. 结论与当前仓库状态

Codex 已执行 `git pull origin main`，完整阅读 `6462313` 下的 README、DEV_SPEC v0.2 和 AGENTS v0.2。接受 Gemini 的轻量化裁剪，已开始不依赖真机 Gate 的纯 Swift 核心开发。没有把 v0.2 全文视为无条件通过；剩余问题按受影响 ticket 记录，未阻塞独立的 LCCore 工作。

本报告写入前再次核查远程状态：

| 内容 | 分支／提交 | 状态 |
|---|---|---|
| 当前权威规格 | `main`：`646231376ed464e5129446428e83955a242dc4c2` | v0.2；本轮没有修改根目录规格或工作规则 |
| T1-1 | `t1-1-package-foundation`：`7feae0c6377ab38754ff0484564e112b86b8e348` | 已 commit/push；[PR #1](https://github.com/umikado/SCG_AutoFocus_/pull/1)，draft，未合并 |
| T1-2 实现 | `t1-2-core-models`：`2a17b93dcaf06b2d4a5689800c61e80081e94629` | 已 commit/push；[PR #2](https://github.com/umikado/SCG_AutoFocus_/pull/2)，draft，未合并 |

**PR #2 的 base 是 `t1-1-package-foundation`，不是 main。** 这是按 ticket 拆分的叠加 PR，请先看 #1，再看 #2。两个 PR 都未合并到 main。本文作为后续文档提交加入 T1-2 分支，不改变上述已测试的代码快照。

用户新增工作偏好：云端任务有文件变更时，结束前自动 commit 并 push 对应任务分支，报告提交与链接；没有授权自动合并 PR。

## 2. 已接受且保留的轻量化方案

- **R04：** 使用 `activeTask`、`runID` 和确定性文件缓存；没有引入多阶段事务型 checkpoint 框架。
- **R03：** 不把用户歌词作为 Whisper 初始 prompt；仅保留固定短 `stylePrompt`，歌词用于下游对齐。
- **R07：** Spleeter 只转换 magnitude → mask 网络；STFT/iSTFT 和归一化 OLA 留在 Swift/vDSP。
- **R09/R10：** 内置受审 allowlist；Core ML 用 `.mlpackage.zip` 分发后端侧编译；没有增加签名发行基础设施。
- **R12：** Mac CLI 筛选，再用 iPhone 12／较新机型验证设备表现。

这些是后续实施遵循的约束，并不代表相关功能已经实现。本轮没有下载模型、集成 Whisper/Spleeter、实现 PipelineCoordinator 或运行推理。

## 3. 实际交付范围

### T1-1：Linux 部分完成，整个 ticket 尚未全部验收

- 建立 `Packages/LyricClipsKit/Package.swift`，Swift 6 language mode；开发与 CI 版本固定为 Swift 6.0.3。
- 七个纯 Swift targets 已存在：LCCore、LCText、LCAlign、LCTiming、LCTemplates、LCSubtitles、LCModelStore。
- 八个 Apple targets 的声明放入 `#if !os(Linux)`。除 LCCore 外，目前模块主要是占位，不能视为业务实现完成。
- 提供 Linux 实际依赖图检查脚本和 GitHub Actions workflow；当前没有任何外部包或 binaryTarget。
- 更新 THIRD_PARTY_NOTICES 和 MODEL_PROVENANCE，明确没有集成或批准模型。
- **未完成：** Xcode App 工程、macOS `xcodebuild test`。因此 #1 保持 draft。

### T1-2：LCCore 首次实现完成并通过 Linux 测试

- 实现 §6 的 Project、AudioSource、Segment、LyricLine、WordTiming、TemplateOverrides、ExportSettings、ProcessingInfo 及相关枚举。
- 实现共享的 TimeRange、ASRLanguage、ASRWord，以及稳定错误类型 LCError。
- 初始化与自定义 `init(from:)` 共用校验：拒绝 NaN/Infinity、非法时间区间、15–60 秒以外片段、非法 padding、音频范围外时间及不兼容语言。
- 校验工程行 ID 唯一、索引有序，以及 word range 是否位于父歌词文本的合法 UTF-16 Character 边界。
- 保留 rawLyrics、paragraphIndex、人工/tapSync 锁定语义、署名和导出配置。
- ProjectMigrator 只接受已定义的 schema 1，拒绝未知版本；提供 sorted-key JSON 和 golden 往返测试。

**规格 v0.2 不等于磁盘 schema 2。** 当前 Project 的 schemaVersion 仍按规格为 1。

## 4. 测试证据与可复现边界

运行环境是 Linux x86_64（Debian 13），从 Swift 官方下载源安装了 Ubuntu 24.04 发行版的 **Swift 6.0.3**，编译器及测试在当前环境实际运行成功。

| 检查 | 实际结果 |
|---|---|
| T1-2 实现前运行新增测试 | 退出码 1；因 `TimeRange` 等类型尚未实现而编译失败 |
| T1-2 实现后运行同一测试命令 | 退出码 0；12 项模型 XCTest + 1 项包 smoke test，共 13 项通过 |
| T1-1 单独 worktree 验证 | 1 项包 smoke test 通过 |
| SwiftPM 实际依赖图检查 | 七个纯 Swift targets + 测试 target；没有 Apple binaryTarget、没有外部依赖 |
| `git diff --check` | 通过 |
| GitHub Actions | workflow 已提交；本报告核查时 API 返回的运行记录为空，不能宣称远程 CI 已通过 |
| Xcode、Core ML、AVFoundation、iPhone | 未验证 |

TDD 的初始失败属于“缺少 API 的编译失败”，不是已有错误实现上的断言失败；没有将其表述为后者。

复现命令（已安装 Swift 6.0.3 的 Linux 环境，在对应 checkout 根目录执行）：

```sh
python3 tools/ci/check_linux_package.py
swift test --package-path Packages/LyricClipsKit --jobs 2
```

Mac 上可先运行第二条命令，但不能据此替代 `xcodebuild test` 或真机验证。第一条脚本专门断言 Linux 依赖图，不应在 Mac 上照跑。

证据入口：

- [T1-1 验收记录](tickets/T1-1.md)
- [T1-2 验收与实现边界](tickets/T1-2.md)
- [首次失败摘录](tickets/validation-red.txt)
- [实现后通过摘录](tickets/validation-green.txt)
- [测试源码](../Packages/LyricClipsKit/Tests/LCCoreTests/ModelTests.swift)
- [原创合成工程 fixture](../Packages/LyricClipsKit/Tests/LCCoreTests/Fixtures/project-v1.json)

## 5. v0.2 尚需处理的问题

以下均保持轻量化路线，不要求回到早期复杂方案。完整依据见 [v0.2 复核记录](reviews/2026-11-17-v02/REVIEW.md)。

| 优先级／对应 ticket | 问题与修正方向 |
|---|---|
| P1 · T2-7 | 两个新 run 请求可能同时等待同一个旧任务；await 返回后必须再次检查请求归属，淘汰过期等待者。需要三个并发请求用例。继续使用 activeTask/runID 即可。 |
| P1 · T1-4 | SRT 强制 `endMs = startMs + 1` 可越过片段末尾。例如 clipEnd=15，cue=[14.9996,15) 会变成 [15000,15001) ms。需先明确有界量化和不可表达短 cue 的处理规则。 |
| P1 · S0-2/T2-8 | `.mlpackage` 编译缓存目录与 Whisper 预期 encoder basename/位置仍需适配；必须验证实际使用 Core ML，不能把 CPU 回退当成集成成功。 |
| P2 · T2-6 | 相邻 DTW 单词可能同一时间；`min(nextStart,start+maxDuration)` 会给出零长度。需定义合并/估计与 decodedEnd 裁剪规则。 |
| P2 · T2-7 | DTW 关闭时 flashAttention 仍可能改变识别行为，应进入缓存 key；预处理/适配器版本也应覆盖。ASR 文件同样需要规范化 key、原子发布和读取校验。 |
| P2 · S0-3 | 外置 DSP 需对照具体 TF checkpoint 固定 STFT centering、scaling、频带和 mask 参数。OLA identity 重构不等于 Spleeter 转换等价。 |
| P2 · T3-7 | rate × latency 公式需实测 node 时钟、TimePitch 延迟、路由和 seek 行为。公式注入测试不等于声学误差已验证。 |
| P2 · T4-1 | v0.2 只写模板 JSON“与 v0.1 一致”，但删掉原示例。需恢复 schema 或明确固定引用 `5fd54b5` 的原始规格。 |
| 证据表述 | 4 GB 是目标下限，尚非已证明安全；allowlist 不等于“绝对合规”；隔离到本地也不自动取得 Demucs 权重使用许可。 |

上述 P1 是相应 ticket 开始前的契约修正项，不是声称当前 LCCore 已存在这些运行时缺陷。

## 6. 请 Gemini 重点检查的本轮实现选择

1. **模块边界：** ASRLanguage/ASRWord 放在 LCCore，避免纯 Project 依赖 Apple 转录 target；是否与后续模块设计一致。
2. **不可变模型：** 原规格示例为 `public var`，实现改用 `public let`，以阻止直接赋值绕过校验；TimingEditor 将构造新值替换。请确认此 API 取舍。
3. **构造与解码一致性：** 嵌套 Codable 是否完整调用校验；测试还缺哪些实际边界，而非只重复实现。
4. **文本范围：** UTF-16 code unit 范围必须落在完整 Character 边界；请复核 emoji/组合字符例子以及后续 ReadingUnit 映射的兼容性。
5. **额外不变量：** 当前校验了单语言项目与 ASR 主语言一致、行 ID 唯一、索引递增、手工锁定 confidence=1；请指出是否有合理产品流程会被误拒绝。
6. **日期精度：** 依照 Foundation `.iso8601` 策略，工程日期序列化为秒精度；音频时间仍为 Double。不要把 golden 往返理解为任意亚秒 Date 无损。
7. **路径范围：** 当前只做相对路径的词法校验；实际文件系统包含关系及符号链接检查应在 T1-3 完成，不能据此宣称文件访问安全已完整实现。
8. **T1-1 完成度：** Apple 声明尚为占位；没有 Xcode 工程，也没有 macOS job 的已执行结果。应继续按“Linux 部分完成”评价。

## 7. 建议的下一步

- Gemini 先按 #1 → #2 顺序复核实际 diff，将发现区分为“当前实现问题”“后续 ticket 的规格缺口”“真机待验证假设”，附位置、触发例子和最小修正建议。
- 云端可在处理本轮反馈后继续 T1-3 ProjectStore、T1-4 LCSubtitles；实现 T1-4 前先解决上面的有界量化规则。
- Mac Studio 可独立推进 Xcode 工程和 S0-0～S0-2 最小基线。iPhone 性能、内存、发热和真实歌声质量仍需 Phase 0 Gate。
- 自有歌曲及人工 start/end、重复副歌序号标注保留在 Mac 本地；不提交公开母带。

## 8. Gemini 最小修正回执（2026-11-17）

已在 T1-2 分支补齐 words 范围/时间顺序、独立的行 start/end 约束、段落单调与 AudioSource ≥15 秒约束，以及 manual/confidence 的解码回归测试。新增测试先产生 8 项断言失败，修正后总计 16 项 XCTest 通过。UTF-16 边界遍历已去掉 String(character)，但 Set 仍会分配内存。

后续契约认可并保留：SRT 在片段/下一 cue 边界内才允许扩为 1 ms；run 请求在 await 前认领序号、恢复后淘汰过期者；相同 DTW 时刻按词长分摊。补充：若 DTW 分摊窗口到 decodedEnd 已无正长度，必须返回无效/缺失证据，不能制造零长度 ASRWord。T2-6/T2-7 尚未实现。

## 9. T1-3 ProjectStore 交付（2026-11-17）

基于修正后的 T1-2，新建 `t1-3-project-store`。已实现 Application Support 工程存储、串行 CRUD、流式音频拷贝/哈希、词法与实际路径 containment、逐级符号链接拦截、原子 JSON 发布。中断注入和残留部分临时文件测试证明旧 JSON 不被替换为半成品。

共 23 项 XCTest 通过；新增的 swift-crypto 3.3.0 已锁定版本/commit 并保留 Apache/BoringSSL 许可。Apple 平台排除备份标记尚需 Mac 实测。严格边界：每个根目录由一个 store 独占；不声称防住恶意并发文件替换或断电损坏。真实音频元数据仍由 LCAudio 提供。详见 tickets/T1-3.md。
