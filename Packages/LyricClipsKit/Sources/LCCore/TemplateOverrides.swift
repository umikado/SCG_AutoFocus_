import Foundation

/// TemplateOverrides value, validated on construction and decoding.
public struct TemplateOverrides: Codable, Hashable, Sendable {
    /// Persisted user choice for the SCG credit.
    public let showCredit: Bool
    /// Optional sandbox-relative image path.
    public let customBackgroundRelativePath: String?

    /// Constructs a validated immutable value; edits must construct a replacement.
    public init(
        showCredit: Bool = true,
        customBackgroundRelativePath: String? = nil
    ) throws {
        if let customBackgroundRelativePath { try relativePath(customBackgroundRelativePath) }
        self.showCredit = showCredit
        self.customBackgroundRelativePath = customBackgroundRelativePath
    }

    private enum CodingKeys: String, CodingKey {
        case showCredit, customBackgroundRelativePath
    }

    /// Decodes using exactly the same invariants as direct construction.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            showCredit: container.decode(Bool.self, forKey: .showCredit),
            customBackgroundRelativePath: container.decodeIfPresent(String.self, forKey: .customBackgroundRelativePath)
        )
    }
}
