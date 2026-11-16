# AGENTS.md 修订建议（未启用）

以下可在采用修订后的 DEV_SPEC 时替换原工作规则；本文件不改变本轮用户授权范围。

- 当前用户请求决定任务范围；DEV_SPEC.md 描述产品约束。先核对适用版本及已记录决策，不把文档中的建议当成发送邮件、发布、创建远程资源或通过验收的授权。
- 按 DEV_SPEC 的阶段与 ticket 依赖顺序工作，保留 Phase 0 Gate。有远程仓库时一张 ticket 一个 PR，标题以 ticket ID 开头；未配置远程时按 ticket 提供本地分支/补丁及同样的验收记录，不虚构 PR。
- 对核心算法、持久化和状态机先写有意义的失败测试再实现。每票记录：逐项验收、实际运行命令/结果、未验证项、Mac/模拟器/真机步骤。文档和低风险配置变更采用相应校验，不添加只复述实现的测试。
- 纯 Swift targets 只依赖 Foundation、Linux 的 FoundationNetworking 及已批准的 swift-crypto；SPM manifest 必须从 Linux 依赖图中排除 Apple binary targets 和专属依赖。源码条件编译不能替代依赖图隔离。
- 使用锁定的 Swift 6 工具链与 strict concurrency；public API 写文档注释。锁定 SwiftFormat/SwiftLint 版本与团队配置；Apple 代码必须通过实际 macOS/Xcode 构建后才可标记已验证。
- 禁止 FFmpeg、x264、GPL/AGPL 依赖、analytics/广告/崩溃上报 SDK，以及上传用户音频、歌词或其标识内容的代码。
- DEBUG 不代表模型获得许可。没有覆盖指定用途的许可证据，不下载或集成 HTDemucs 权重；经批准的研究实验也必须与生产目标和生产 manifest 隔离。
- 新增依赖更新 THIRD_PARTY_NOTICES；涉及模型另更新 MODEL_PROVENANCE，记录源文件/转换产物 hash、版本、工具链和使用/再分发依据。不得把未经审核的模型自行标 verified。
- 生产运行时检查全部模型及 companion 的受审许可清单，覆盖远程 defaults、非默认选项与本地缓存；不能仅依赖 CI 或符号扫描。
- 测试只用原创合成数据或授权范围明确的 SCG 自有曲目/歌词。拥有曲目用于测试不等于授权公开提交母带，未明确公开授权时真实素材留在本地，仓库只保存非敏感 fixture/指标。
- 时间统一为原曲绝对秒（finite Double）；使用半开区间。字幕先裁剪、再平移、最后量化。原文范围采用已批准的 UTF-16 映射规则，禁止跨字符边界编辑。
- actor 要显式处理重入与 run 状态；底层取消、资源释放、checkpoint、输入 revision、缓存失效都遵守 DEV_SPEC。不得以“已调用 cancel”声称推理已停止。
- 只做当前票相关修改。对影响正确性、许可、持久化或验收的歧义，在实现前记录具体选项和建议；可以继续已明确且独立的工作。常规可逆实现细节自行处理并记录。
- 不自动合并 PR，不改 main 分支保护，不创建 release/tag。真实设备、外部素材或账户配置缺失时明确标待验收，不使用模拟结果冒充。
