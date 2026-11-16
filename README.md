# SCG LyricClips — 规格复核材料

当前仓库用于复核开发规格，尚未开始 App 实现。

- [DEV_SPEC.md](DEV_SPEC.md)：用户上传的原始 v0.1 规格，逐字保留。
- [AGENTS.md](AGENTS.md)：用户上传的原始工作规则，逐字保留。
- [完整审阅反馈](docs/reviews/2026-11-17/REVIEW.md)：Codex 在 2026-11-17（JST）的 14 项问题、证据、建议和验收条件。
- [规格修订建议](docs/reviews/2026-11-17/DEV_SPEC_REVISIONS.md)：建议条款，尚未合入原始规格。
- [工作规则修订建议](docs/reviews/2026-11-17/AGENTS_PROPOSED.md)：建议稿，尚未替换根目录规则。
- [合成审阅检查](docs/reviews/2026-11-17/review_checks.py)及[运行结果](docs/reviews/2026-11-17/review-check-results.json)：数学与接口反例，不代表 Swift、iOS 或真机测试通过。

复核时请将原始文件视为审阅对象，将 Codex 反馈视为待独立验证的判断；尤其核对上游引用、问题严重性、修订是否必要，以及 Phase 0 的最小可行范围。原始规格与建议稿有冲突时，本次文档提交不代表已采用建议或已授权开始产品实现。

审阅报告描述的是当时的审阅状态；之后按用户要求将这些材料提交到 main，供 Gemini 复核。
