# DEV_SPEC v0.1 修订建议（尚未成为施工规格）

本文件是针对 REVIEW.md 的可采用条款。保留用户原文件，不把以下建议自动视为产品决策。建议合入后再将 DEV_SPEC 升到 v0.2。

**1. §5 / §7：固定识别适配器契约（R01、R05）**

- 初始技术验证锁定一个可复现的 whisper.cpp commit、构建配置及 xcframework SHA-256。必须在设备日志中确认实际 Core ML encoder 加载成功，记录 CPU/其他后端回退。
- 若采用本次审阅的 `664c62f7a6668b511c280a58d35ccf3d71ebb637`，DTW 模式同时设置 `flash_attn=false`、`dtw_token_timestamps=true` 及匹配模型架构的 `dtw_aheads_preset`。升级版本后重新验证，不假定其行为不变。
- `LyricLanguage` 用于产品文字；增加独立 `ASRLanguage`。zh-Hans/zh-Hant 映射 zh，ja/en 对应原值；mixed 必须获得主语言，不能直接传给 Whisper。
- `offset` 定义为实际解码 PCM 第一个采样点对应的原曲秒数，通常是 `max(0, segment.start-padding)`；适配器统一把 Whisper 相对时间转换为绝对秒，只转换一次。
- 保留 token ID、原始 token bytes、token probability、原始 DTW 值，先重建合法文本，再形成对齐单元。词结束估计是独立算法，需标记估计来源；无效 DTW 值不得直接变成 0 秒。
- 所有原文文本范围使用 UTF-16 半开区间，归一化单元保留原文映射，编辑位置必须通过字符边界校验。

**2. §6 / §7 / §10：可恢复状态和时间编辑契约（R03、R04、R06、R08）**

- 工程增加 `revision`；每次影响处理结果的变更递增。运行状态包含 `runID`、`inputRevision`、当前阶段、取消状态及已提交 checkpoint。
- checkpoint 包含 schema、阶段、输入摘要、产物相对路径/hash、运行时与算法版本、完成时间；先写产物，校验完成后原子发布 checkpoint。重启时只信任完整且版本匹配的 checkpoint。
- decode key：音频内容摘要、实际采样范围、输出格式、解码算法版本。
- separation key：decode 摘要、引擎 ID、权重 hash、前后处理和窗口参数。
- ASR key：实际输入音频摘要、推理库版本、ggml 与 encoder hash、主语言、prompt token 摘要、DTW/解码选项。首遍默认不使用未知的“片段对应歌词”作为 prompt；用户选行或二次识别的 prompt 路线单列，不能使用人工参考标签给全自动验证集泄露答案。
- alignment key：ASR 摘要、歌词、读音/归一化/对齐版本、候选范围和锁定人工锚点。
- `PipelineCoordinator` 拒绝同时运行第二个任务。取消底层工作并等待安全释放后才允许下一任务；runID/revision 不匹配的迟到结果不得写入工程。
- UI 在 500 ms 内显示取消已请求；后台真正停止所需时间单独记录并在 Phase 0 给出设备上界。不得在底层预测仍使用模型时 unload。
- `AlignmentResult` 增加候选集合、候选歌词范围、normalizedCost、歧义状态及证据不足状态。精确平局必须提示；其他近似阈值在开发集确定并冻结到版本。
- 插值只允许在已选歌词候选范围内部、相邻有效锚点之间进行。区间外歌词不插值。manual 和 tapSync 均锁定；重跑对齐不得修改锁定行，并约束其相邻行。
- `TimeRange` 必须是有限非负秒并满足 start < end；内部时间采用半开区间。读取 JSON、编辑及导出前均验证。未定时行的 start/end 可为 nil，部分定时需有明确状态，不能被当成完整区间。
- 原始歌词保留空行；规范化显示行同时保留段落信息。编辑显示文字不会改 rawLyrics，但会使该行 words/读音/旧自动置信度失效。

**3. §7 / S0-3：分离前后处理（R07）**

- 明确音频采样率、声道数、FFT 长度、STFT hop、窗、中心 padding、幅度缩放、频率裁剪、mask 应用与 iSTFT 参数，写入模型版本描述。
- 模型块级 overlap-add 使用有效窗权重和归一化；定义边界 padding、有效样本裁剪及极小分母处理，保持输入输出采样数一致。
- 不使用“拼接点邻近 RMS”作为唯一正确性标准。恒定值、正弦和脉冲经 identity 分块重构应保持幅度/时长；Spleeter 与 TF 的转换误差按固定参考计算。只有拥有干净 stems 的实验才报告分离 SDR。

**4. §8 / §9 / AGENTS：模型资源与许可门禁（R02、R09、R10）**

- 默认不集成、不下载 HTDemucs 权重。若获得覆盖具体实验用途的许可依据，可在隔离实验 target 中 opt-in；DEBUG 本身不是许可依据。
- Spleeter 保留为候选，记录官方具体权重版本、许可证证据、原文件 hash、转换脚本/工具版本与转换产物 hash。书面确认事项包括商业使用、Core ML 转换和自有 CDN 再分发。
- MVP 的可用引擎、受审模型版本、companion 依赖与 hash 固定在随 App 发布的审核清单。远程 defaults 只能从该清单中选取，不可提升权限或自行声明新模型已受审。需要远程新增模型时另设签名发行与审核流程。
- 每个模型资源写明 `format`、下载/展开大小、解包根目录、适配器期望路径、最小运行时/系统版本和 hash。不得混淆 mlpackage 与 mlmodelc；不允许 bytes=0 的生产资源。
- 下载/解包/编译/装载分阶段校验，拒绝越界展开与不兼容产物；磁盘预算覆盖同时存在的源文件、展开目录、编译目录和临时文件。装载租约存在时不能 purge。

**5. §11 / §12：预览和导出（R08、R13）**

- 导出使用原混音；分离后的人声仅用于识别与编辑辅助。输出时间从 0 开始，原曲时间到视频/音频/字幕的转换共享同一段 segment 定义。
- 字幕先求交：`[max(line.start, segment.start), min(line.end, segment.end))`。有效区间再减 segment.start，最后量化；空区间丢弃并报告，不写负时间或 end≤start。
- end 缺失时，取存在的 nextStart-0.05、start+5、segment.end 的最小值；结果无效则要求修正，不制造非法区间。
- LRC 明确支持多时间标签、metadata、offset 和无文本清屏标记的规则；LRC 与 SRT 的往返只保证各自支持的规范化表示，不保证恢复置信度、行 ID 或所有结束时间。
- 署名按建议采用默认开启/用户可关闭并持久化；片尾卡 MVP 保持关闭，若启用需另定义追加时长的音视频/字幕行为。
- 逐像素一致仅比较同一渲染器输出的编码前 BGRA 帧。压缩成片检查时长、PTS、色彩与可接受图像误差。
- CoreText 测量、实际断行及字体回退都在 Apple 渲染层共用；纯 Swift 布局测试只验证不依赖字体引擎的约束，或使用明确注入的测量结果。

**6. §14 / §15：修订第一周验收（R11、R12）**

- S0-0（新增）：固定工具链、依赖版本、benchmark 格式与合法合成 fixture。纯 Swift 依赖图在 Linux 可构建；Apple 依赖从 Linux manifest 排除。没有 Swift 工具链时报告阻塞，不填写通过。
- S0-1：只有 Passthrough 按钮和一段自有测试音频；无素材时可用原创合成数据验证结构，但不能通过歌声准确率验收。
- S0-2：先 base 无 prompt，确认实际 DTW、encoder 后端、原曲绝对时间及词尾规则；再加 small-q5_1 和 prompt A/B。
- S0-3：Spleeter 转换独立时间盒；失败必须说明具体算子/环境/数值差异，不能阻止 Passthrough 基线完成。
- S0-4：以重复副歌候选、漏行、人工锚点和中日韩混排覆盖对齐契约，保存候选与错误而不只输出最终起点。
- S0-5：先进行小规模筛选，再在保留曲目上确认候选路线。每条记录包含歌曲/片段 ID、参考标注版本、device/OS/build、模型 hash、语言、prompt、实际推理后端、DTW 状态、各阶段耗时、footprint、thermal、覆盖率、误差、失败及取消状态。不写私人歌词到网络日志。
- S0-6：读音验证加入原文范围映射、混排上下文和真实 iOS 构建；封装 MIT、MeCab BSD 及词典许可分别存档。
- Gate：按语言报告全部参考行；漏行、错副歌计失败。不分离路线先达到绝对准确率要求，再讨论相比分离少于 5 个百分点是否值得省成本。原文阈值先作为目标保留，在开发集调整须留记录，确认集不得事后改门槛。没有真机/自有素材则保持待验收。
- Phase 1 只在 Umi 看过实测报告并选择路线、模型、设备范围后开始。

**7. §13 / §17：产品决策记录**

建议保留工作名 SCG LyricClips、iOS 17 和四种本地化；Bundle ID、Team、CDN 域名、订阅 URL 标为占位。明确工程是否排除系统备份及其恢复代价。Apple 隐私标签/Required Reason API/上架条款以发布前官方文件与实际调用核对，不能由“不上传音频”一句话推导全部结论。
