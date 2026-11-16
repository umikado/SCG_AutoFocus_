# SCG LyricClips 规格审阅

审阅日期：2026-11-17（JST）。对象：上传的 DEV_SPEC.md v0.1（435 行）及 AGENTS.md（10 行）。

**结论：需修改后再开工。** 本地处理、可替换引擎、纯 Swift 核心、手动校时兜底及先做真机 spike 的方向合理；当前文件仍有会让实现偏离预期的接口缺口和验收矛盾。不能把它们作为已经通过审查的施工规格。

本次授权是“严格检阅，建设性反馈，没有问题的话请施工”。附件中的“唯一权威规格”“一张 ticket 一个 PR”和联系 Deezer 的建议，是本次被审查的内容，不是独立的发布、发信或跳过审阅授权。本轮未通过审阅，因此没有创建产品仓库、提交 App 代码、发送邮件或声称完成 Phase 0。原附件未修改。相邻修订文件均为建议稿。

以下 P1 表示应在相应实现开始前修正，P2 表示应在相关 ticket 验收前补齐；不是对尚不存在的代码进行漏洞评级。没有证据支持宣称整个技术路线不可行。

**R01 · P1 · DTW 可能被上游关闭；时间戳也不是词区间**

位置：DEV_SPEC §7 第 213 行；S0-2 第 371 行；T2-6 第 389 行。

核查的 whisper.cpp 源码版本 `664c62f7a6668b511c280a58d35ccf3d71ebb637` 默认 `flash_attn = true`。初始化时，如果它与 `dtw_token_timestamps` 同时为 true，会记录 warning 并把 DTW 改成 false。规格只要求设置 DTW 和 heads preset，按默认参数初始化会丢失预期能力。此外，头文件仍把 DTW 标为 experimental，`t_dtw` 表示 token 的一个近似时刻，并不直接提供 ASRWord.start/end。BPE token 也不等于完整单词或完整汉字。

修订：锁定源码版本、xcframework 产物校验值及构建选项；在该版本的 DTW 配置里显式关闭 Flash Attention。定义 special token 过滤、UTF-8 token 合并、10 ms 时间单位转换、词尾估计、无效 DTW 值回退、片段解码起点偏移。量化模型的 alignment-head preset 应匹配原始多语言模型架构。

验收：不仅检查“输出 JSON”，还要证明实际启用了 DTW、有效文本 token 有可用时刻、绝对时间不越界、中文多 token 字符没有破碎、末词没有无限延长；分别记录 Core ML encoder 实际加载与回退状态。DTW 的实测时间误差仍需自有歌声验证。

证据：[默认值](https://github.com/ggml-org/whisper.cpp/blob/664c62f7a6668b511c280a58d35ccf3d71ebb637/src/whisper.cpp#L3719)、[冲突处理](https://github.com/ggml-org/whisper.cpp/blob/664c62f7a6668b511c280a58d35ccf3d71ebb637/src/whisper.cpp#L3823)、[DTW 时间写入](https://github.com/ggml-org/whisper.cpp/blob/664c62f7a6668b511c280a58d35ccf3d71ebb637/src/whisper.cpp#L9312)、[头文件](https://github.com/ggml-org/whisper.cpp/blob/master/include/whisper.h)。源码固定链接内容已与本次读取的 master 文件逐字比对一致。

**R02 · P1 · DEBUG 不能充当模型权重使用许可**

位置：DEV_SPEC 第 151、274、370、372、374 行；AGENTS 第 5 行。

Demucs 作者在 #327 的确写了 “The model weights are not covered by the MIT license, and are provided only for scientific purposes.” 当前 adefossez 维护仓库又明确说权重许可不清楚且作者无法授予许可。它支持“现有权重不能按 MIT 放进商业产品”的判断，但不能推出“公司产品开发只要是 DEBUG 就一定可用”。编译配置与使用授权是两回事。这个结论也不应扩大为 Demucs 架构、MIT 代码或自行训练权重全部禁止商用。

修订：默认 spike 矩阵先去掉 HTDemucs；只有确认具体权重与具体研究用途被许可时，才作为独立、明确 opt-in 的实验项。不要纳入主 App target、默认下载 manifest 或常规 CI 自动下载。授权审核应覆盖转换、再分发和公司内研发用途。

Spleeter 的 JOSS paper 第 85 行确实写明代码和预训练模型 MIT；README 第 114 行仅明确代码许可。本次读取的 #898/#957 回复没有给出维护者确认。书面确认是合理的商业风险管理建议，并不是 MIT 本身要求每个使用者额外取得邮件许可。对商业候选应保留具体官方权重版本、来源及转换链的证据。

验收：未经确认的模型不可通过 DEBUG 开关、远程 defaults 或备用下载地址进入生产使用路径。

证据：[Demucs 作者原回复](https://github.com/facebookresearch/demucs/issues/327#issuecomment-1134828611)、[当前 README 许可说明](https://github.com/adefossez/demucs#license)、[Spleeter paper](https://github.com/deezer/spleeter/blob/master/paper.md#L85)、[Spleeter README](https://github.com/deezer/spleeter#license)、[#898](https://github.com/deezer/spleeter/issues/898)、[#957](https://github.com/deezer/spleeter/issues/957)。

**R03 · P1 · 缓存 key 漏了会改变识别结果的输入**

位置：DEV_SPEC 第 214、233、374、390 行。

现有 key 只有 `audio, segment, engineID, modelVersion`，但 ASR 结果还依赖语言、prompt、DTW 配置、分离输入和推理实现版本。“只改歌词不重新识别”与“歌词作为 initialPrompt”冲突。若复用流水线缓存，S0-5 的有/无 prompt A/B 可能读到同一份结果，实验本身失效。

修订：分别定义 decode、separation、ASR、alignment 的输入摘要。ASR key 包含实际输入音频摘要、实际模型与 encoder hash、运行时版本、语言、prompt token 摘要、时间戳/解码选项；alignment key 再包含歌词与读音算法版本、手动锚点。歌词修改且有效 prompt 改变时，旧 ASR 必须标记过期或重跑，不能当作新的有效识别结果。benchmark 关闭结果缓存，保留模型预热。首次识别时还不知道“片段对应歌词”，prompt 的获取流程必须明确；若测试中用人工参考选中了正确歌词，必须单列为有人工提示的实验，不能当作全自动路线成绩。

验收：只改颜色命中处理缓存；只改歌词在 prompt 关闭时复用 ASR；改 prompt/语言/分离模型或 ASR 参数使正确阶段失效；缓存与未缓存结果一致。

**R04 · P1 · actor、detached task 和阶段保存不足以保证单任务、取消与恢复**

位置：DEV_SPEC 第 227–244、390 行。

actor 在 await 处可重入，不会自动阻止第二次 run；`Task.detached` 不自动继承调用任务的取消。“每块检查一次”也不能保证耗时 Core ML prediction 内的 500 ms 取消。project.json 的字段没有 checkpoint、输入 revision 或中间产物元数据，仅保存工程不能恢复未持久化的 ASR 词。取消后立即释放模型或启动新任务还可能与原生调用冲突。

修订：显式 run 状态机、任务句柄、runID 和 project revision；取消请求传播至底层；旧任务完成后禁止覆盖新工程。将“UI 确认取消 ≤500 ms”与“推理安全退出时间”拆开测量。落盘采用 checkpoint + 文件 hash + 原子提交；只恢复完整且输入版本一致的阶段。系统杀进程后重启未完成阶段，不承诺在任意指令处续算。后台时间不足则取消并保存已完成阶段。

验收：两次并发 run、取消中再次启动、修改工程后旧结果回调、各阶段写盘中断和损坏产物，都有确定结果；真机测量底层最长不可中断时间。

**R05 · P1 · 混排语言与文本位置契约不完整**

位置：DEV_SPEC 第 122、131–132、156、181、213、218、384–385 行。

产品语言是 `zh-Hans/zh-Hant/ja/en/mixed`，Whisper 接受的是模型支持的语言代码，中文需映射到 `zh`，`mixed` 不能原样传入。日文汉字与中文共享 Han script，仅靠文字类别无法决定读音。全角折叠、去标点、删除括号、组合字符处理之后，`Range<Int>` 是原文 UTF-8、UTF-16 还是 Character 偏移也没有约定；后续拆分、高亮或时间映射会产生不兼容实现。

修订：分开表示显示语言、读音上下文和 ASR 主语言。MVP 的 mixed 让用户指定主语言，并把 code-switch 质量纳入 spike；Han 按上下文和用户指定语言解释。统一所有文本范围为原行 UTF-16 半开区间，归一化结果保留到原文的映射；所有实际编辑必须落在合法字符边界。括号默认保留歌词内容，只有明确识别的舞台说明可排除，避免删掉真正唱出的括号歌词。

验收：繁简、日文汉字夹英文、组合重音、emoji、半角片假名、括号内真实歌词都有映射与识别选项用例。

**R06 · P1 · 对齐结果无法完整表达歧义与人工保护**

位置：DEV_SPEC 第 134–138、176–179、220–223、295–297、386 行。

`AlignmentResult` 只有一组结果和一个 suggestedLineRange，无法让 UI 展示“第几次副歌”的多个候选。近似最优解“代价差 <5%”没有分母和零代价规则：重复副歌的两个完美匹配均为 0 时，直接取最优成本的 5% 会漏报平局。无匹配行插值也必须限制在选中候选范围，否则整首未出现在片段的歌词会被塞入 60 秒内。tapSync 的来源与“只保护 manual”不一致；事后跳过 manual 行仍可能让邻行穿过人工锚点。

修订：新增候选列表和明确的 ambiguity 状态；成本按单元数归一，精确平局一律歧义；没有足够证据时不擅自认定某次副歌。先限定候选歌词区间，再对其内部漏行做有界插值；区间外保持未定时。manual/tapSync 均成为锁定锚点，对齐相邻区间时受其约束；文本修改后清除过期 words/读音映射。

验收：三段相同副歌、最佳成本为零、全替换、片段外未匹配歌词、无 ASR、人工锚点夹在自动行之间、tapSync 后重跑，都不能静默覆盖或制造高置信度结果。`confidence` 是启发式分数，不能显示成已校准的正确概率；人工确认状态单独展示。

**R07 · P1 · Hann 拼接缺少归一化与边界规则**

位置：DEV_SPEC 第 212、388 行。

25% overlap 对应 75% window hop。Hann 窗按此 hop 直接加和不具有恒定窗和。用恒定输入的合成检查，内部窗和在约 0.292893 到 1 之间变化，约 10.67 dB；这是未归一化拼接的数学示例，并非测得 Spleeter 有这个缺陷。仅检查“拼接点前后 RMS <1 dB”不能证明整个重叠区没有周期性音量调制，真实音乐的自然动态也会让该测试误报。

修订：明确按有效窗权重和归一化，定义首尾 padding、分母为零的处理、长度裁剪和声道一致性；STFT/iSTFT 的重构窗规范与模型块级拼接规范分别规定。转换脚本同时固定 n_fft、hop、窗口、幅值缩放、频带裁剪与 mask 重建参数。

验收：恒定信号、正弦、脉冲及非整窗口长度在 identity 引擎下重构，检查整个区间幅度/长度/边界；真实音乐质量与数值重构测试分别评价。

**R08 · P1 · 片段裁剪、字幕末尾和 tap 时钟缺少统一规则**

位置：DEV_SPEC 第 108、170、186、211、295、328–333、356 行。

“导出时减 segment.start”不够。例如片段从 30.0 s 开始，歌词区间为 [29.8,31.0)，直接平移产生负时间。片段末端也需要裁剪；纯 LRC 没有 end，会把上一句保持到下一句开始，无法自然表达句后空白。最后一行缺 end、两行过近、SRT 毫秒舍入后成为零长度、LRC offset/multi-tag 等都没有规则。tap 的播放器 render time、听到的声音和墙钟时间不是同一时钟，变速下 -80 ms 的语义必须固定。

修订：采用半开时间区间；先与 segment 求交，再平移、再按格式量化，最后校验有效区间。缺 end 的回退先取 nextStart-0.05、start+5、segment.end 的最小值，若不大于 start 则报出无效行，不写坏字幕。LRC 明确保留空白时间标记及支持的输入语法，不能声称有损格式往返保留所有工程数据。输出音轨明确使用原混音，vocals 仅用于对齐；所有视频/音频 PTS 从导出 0 点开始。时间值必须 finite，解码和编辑都校验，而非仅 init。

验收：跨片段边界的行、0/末尾 padding、59.995 s、超过一小时、NaN/Infinity、字幕空白区和缺失 end；seek/暂停/变速/音频路由变化后的 tap 注入实验。误差需分别报告系统时钟误差与用户反应偏差。

**R09 · P1 · 生产模型门禁仅检查 defaults，覆盖不完整**

位置：DEV_SPEC 第 152、259–265、284、409 行。

CI 只检查构建时的默认模型，但默认值可以在发布后由远程 manifest 改写；非默认可选模型、companion encoder、旧缓存也能进入运行路径。manifest 自称 `provenance: verified` 不能代替审核证据。SHA-256 能检验文件与 manifest 一致，却不能独立证明 manifest 的发行者。

修订：生产 App 维护受审模型/引擎许可清单，运行时检查完整依赖闭包及已缓存文件。MVP 可以先用随 App 发布的固定模型清单与 hash，manifest 仅在允许的版本中选择；若一定要无需发版新增任意模型，再设计签名与审核发布链。将“manifest 必须签名/固定 hash”与“仅 HTTPS”的冲突消除，不把两者写成同时成立。

验收：远程改默认到未受审模型、未受审 companion、未知引擎、损坏缓存均被拒绝；仍可进入手动模式。不要只扫描 HTDemucs 符号来判断权重不存在，因为权重是数据。

**R10 · P2 · Core ML 下载物格式与装载契约冲突**

位置：DEV_SPEC 第 255–263、371、382、391 行。

正文分发 `.mlpackage.zip` 并在设备编译，示例 companion 却是 `.mlmodelc.zip`。两类资源的解包、兼容性与编译路径不同。companion 的示例 bytes 为 0，不能支持准确空间预算/蜂窝确认；ZIP 解包方案也没有落到允许依赖内。Whisper 自动寻找的 encoder 文件名和目录布局必须匹配锁定运行时，不能只下载到任意 ModelID 目录。

修订：逐资源声明 format、unpackedBytes、expectedRoot、engine compatibility 和各文件 hash；选择明确的分发路线。解包拒绝越界路径/符号链接及超额展开，校验后原子发布。缓存区分源模型、编译模型和运行时/系统兼容性；空间估计同时包含下载、展开、编译及临时文件峰值。并发 ensure/purge 与正在使用的模型需要明确租约规则。

验收：缺失 encoder、命名不匹配、旧编译缓存、断网续传失效、编译时磁盘不足及解包失败均可恢复，不能把部分下载标记 ready。

**R11 · P2 · Linux 可测试性需要在 SPM 依赖图隔离**

位置：DEV_SPEC 第 68、79–95、102、358、365、378 行；AGENTS 第 4、9 行。

`#if canImport` 只能保护 Swift 源码，不能自动阻止 SwiftPM 解析/下载 Apple binaryTarget 或构建不兼容依赖。Linux `URLSession` 通常还需 `FoundationNetworking`。全平台纯 target 与 iOS targets 放在同一包时，单靠 test filter 也不足以隔离依赖解析。工具链、formatter/linter 版本不锁定，则“默认配置”不能产生可重复结果。

修订：在 manifest 按宿主平台排除 Apple target、binaryTarget 和依赖，或分为 Core/Apple 两个包；保留 FoundationNetworking 的系统模块例外。固定 Swift 6 小版本与 CI/Xcode 版本，先运行纯包测试验证依赖图；Apple 包用 xcodebuild 验证 Swift strict concurrency、C 回调生命周期和 Core ML 对象隔离。

验收：Linux 不下载 Apple binaryTarget，所有纯 target 测试实际执行；Mac/模拟器测试单独报告。当前环境未发现 swift 或 xcodebuild，因此本轮没有任何 Swift/iOS 编译通过的结果。

**R12 · P2 · benchmark 目前不足以支撑产品路线决策**

位置：DEV_SPEC 第 32–36、228、285、363–375、376、399 行。

9–15 首歌 × 12 配置 × 2 台设备 = 216–360 次运行，尚未包含冷/热启动与复测；“一周”只能是投入时间盒。LRC 通常只有行起点，既不能验证行结束/空白，也不能独自提供分离 SDR 所需的干净人声参考。“相差 <5 个百分点就取消分离”还要先要求不分离方案达到绝对准确率下限；两条路线都很差但相差很小不能算通过。仅统计匹配成功的行会高估准确率。

修订：先跑 Passthrough + base 无 prompt 的最小链路，再逐项增加变量。固定调参集与保留验证集；按语言、歌曲/片段分层汇总，漏行和错副歌计失败，单独报告覆盖率、P50/P90、±300 ms 比例及人工修正成本。重复副歌还需标注对应歌词 occurrence。补充逐行 start/end 人工参考及授权范围记录。若没有干净 vocal stem，将转换验证定义成相对 TF 输出的数值/音频误差，不称它为真实分离质量 SDR。

峰值内存用实际进程 footprint/Instruments，`os_proc_available_memory` 只作运行时余量信号；不能把 1.2 GB 余量阈值当作防 jetsam 保证。A14 阈值与旧机降级规则先统一，设备限制最终由真机结果决定。500 ms 取消、≤20 s 导出、≤30 ms tap 等均是待验证目标，不是已知能力。首周无法达标时输出明确 no-go 或缩减路线的建议。

**R13 · P2 · 渲染一致性的验收对象不明确**

位置：DEV_SPEC 第 302、320、327、360、403 行。

如果“导出帧逐像素一致”指解码后的 H.264/HEVC，因有损编码和色彩转换不能要求与预览逐像素相同。纯 Swift LayoutEngine 也无法用 Foundation 精确复现 CoreText 的字体测量、禁则、fallback 和自动缩字。

修订：逐像素一致仅比较同一渲染器、同一字体/配置下编码前的 BGRA 帧；编码后的成片检查 PTS、色彩、可接受图像差异与音画同步。纯层负责逻辑布局与参数，Apple 层统一完成字体测量和实际断行，或向纯层注入测量结果。

验收：编码前/后测试分开；golden 按可复现的字体与 OS 环境固定；预览和导出调用同一段实际排版代码。

**R14 · P2 · 隐私与离线承诺需要按实际行为定义**

位置：DEV_SPEC 第 184、255、339–349 行。

模型设了 excludedFromBackup，工程和导入音频尚未规定系统备份策略；“只在本机”需要说明是否包括 iCloud 设备备份。打开自家订阅网页不自动证明可以填写“不收集数据”，需要核查实际网页收集、服务方日志、用途及 Apple 当前披露规则。Required Reason API 应由实际调用决定，不能凭示例 reason code 固定照抄。

修订：明确本地工程备份/恢复策略和用户提示；手动编辑及本地已就绪模型允许完全离线启动；模型网络请求不携带曲名、歌词、文件名或音频摘要。隐私声明、订阅页和 xcprivacy 在 T6-2 逐项核对。

本次尝试读取 Apple 官方隐私/Required Reason API/ODR 页面被环境网络代理拒绝（403），因此没有把相关当前规则、iOS 27 时间性陈述或具体 reason code 标为已验证；这里属于待核实项，不声称已证实违规。

**其余需同步的规格冲突与漏项**

| 位置 | 问题 | 建议 |
|---|---|---|
| G2 第 17 行 / T3-2 第 394 行 | 空行作段落 vs 去掉空行 | 保留原文与段落元数据；显示时可不生成空歌词行 |
| §2 第 35 行 / §7 第 238 行 | A14 以下只手动 vs 先尝试 base | 默认手动，可用性探测通过后是否开放 base 由 Phase 0 定义 |
| §0、§7 第 9、211 行 / T3-3 | 选段前需要整曲波形，却声称只解码片段 | 若要整曲波形，允许流式扫描生成低分辨率峰值；推理严格限于选段 |
| 第 127、211 行 | offset 缺少定义 | 设为实际解码起点 max(0, segment.start-padding)，只加一次 |
| §6 / §10 / §12 | TemplateOverrides、ProcessingInfo、ExportSettings、错误类型未完整定义 | 在对应票前补字段/缺省值/解码校验；不要靠各模块自行猜测 |
| §11 / §12 | 封面来源、署名用户选择、片尾卡音轨与字幕时长未建模 | 加工程持久化字段；片尾卡留到后续，MVP 默认关闭 |
| 第 35 行 | 白名单可能把新设备错判低端 | 未知设备走能力探测和安全降级，不直接按不支持分类 |
| 第 435 行 | “iOS 27 已发布”与最低系统决策混在一起 | 写可核验来源/日期；最低 iOS 17 暂保留为产品假设 |
| AGENTS 第 2、10 行 | 没有远程仓库时无法按票开 PR；歧义只能在 PR 里问太晚 | 本地分支/评审稿可替代交付载体；影响架构的问题在实现前记录 |

**已核实、可以减少不确定性的地方**

- [OpenAI Whisper README](https://github.com/openai/whisper#license) 明确写代码与权重均为 MIT；仍需记录实际 ggml/encoder 转换产物的来源。
- [Mecab-Swift LICENSE](https://github.com/shinjukunian/Mecab-Swift/blob/master/LICENSE) 是 MIT，无需继续把封装本身写成“完全未查明”。vendored MeCab 与 IPADic 声明仍须分别保留和核查；这也不构成 iOS/Swift 6 已兼容的证明。
- 本地处理与手动时间编辑可以独立形成有用的路线；Spleeter 授权确认不应成为所有纯逻辑测试和手动模式的先决条件。

**建议的开工门槛与第一轮范围**

采用相邻 `DEV_SPEC_REVISIONS.md` 的接口修订后，先做一个可失败、可测量的 Phase 0 最小链路：合法测试音频 → Passthrough → 固定版本 Whisper base → 有效 DTW/候选对齐 → 导出测量 JSON。首次阶段只放一个测试场景，随后加入 small-q5_1、prompt A/B、读音方案和 Spleeter；不要同时把 16 个模块铺成空壳来代替可行性证据。

Phase 0 的设备结论必须等待 Mac 构建、iPhone 12 与较新真机测试以及自有曲目，不以合成语音或 Linux 数学检查替代。规格原有 §15 Phase 0 → Phase 1 的 Gate 应保留：由 Umi 根据真实报告选择路线、模型和机型。

**§17 的建议决定（不是已执行的外部操作）**

| 项目 | 建议 | 何时需要用户提供/确认 |
|---|---|---|
| 名称 | 内部继续用 SCG LyricClips | 上架名称另查重；不阻塞纯核心 |
| Bundle ID | jp.scgcreation.lyricclips 保留为占位 | Mac 签名/真机 App 需要可用 Team 与正式 ID，不能假定已注册 |
| Deezer | 建议联系，询问具体权重、商业端侧推理、Core ML 转换及自有 CDN 再分发 | 发信前需要明确发送授权与公司发件身份；本轮未发送 |
| 署名 | 默认开、允许关闭，保存到工程；片尾卡默认关 | 确认产品策略即可，不依赖模型选型 |
| 测试资料 | ZH/JA/EN 各 3–5 首；音频、逐行 LRC、曲目/歌词权利范围；另补 start/end 与副歌 occurrence 参考 | 真机准确率 Gate 必需；纯逻辑先用原创合成文字与模拟时序 |
| 订阅页 | 现有页面适配后复用 | 接入前提供 URL 并核对隐私披露 |
| zh-Hant | 保留现有 MVP 范围 | 无新约束则无需删掉 |
| iOS 下限 | 暂保留 iOS 17，模型能力按 spike 定 | 不因未经验证的版本陈述改产品范围 |

**本轮验证与边界**

完整通读两份附件；读取上述 GitHub 一手资料；将 Whisper 核心证据固定到提交；运行 `review_checks.py` 的 6 个合成审阅检查，结果见 `review-check-results.json`。这些检查证明窗和、缓存遗漏、零代价歧义、裁剪及时间单位的例子，不是产品测试，更不是对真实歌曲准确率的验证。未安装或运行 Swift、Xcode、Core ML、whisper 推理、Spleeter 或真机测试。

输入 SHA-256：

```text
AGENTS.md   5f8496592e66c35d6a16cd0696f205b887ea0d45372556efeefbe7bba23261b7
DEV_SPEC.md 3eb9614f8871f740fc5c59874e4d5b18d0e4b28ebdcf7a9b1204a1313c1ab937
```
