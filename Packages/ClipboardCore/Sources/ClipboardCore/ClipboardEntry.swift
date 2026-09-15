import Foundation

/// One copied text snippet. Text-only, deliberately — MacClip's whole scope
/// is "what did I recently copy," not a general-purpose multi-type
/// clipboard manager (images/files are out of scope for now).
///
/// This is v1's schema: every field here has existed since the very first
/// version, so plain synthesized `Codable` is safe. The moment a *second*
/// schema version adds a new field, switch to a custom `init(from:)` using
/// `decodeIfPresent` + a safe default for that new field — synthesized
/// `Codable` requiring a field that an older saved history.json doesn't
/// have will fail to decode entirely, and a naive `load()` that then
/// silently proceeds with an empty in-memory list will get that emptiness
/// written back over the real file on the next save, destroying real
/// history. This exact bug happened for real in a sibling project
/// (MacSecureSSH) before the lesson was learned — don't relearn it here.
public struct ClipboardEntry: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let copiedAt: Date

    public init(id: UUID = UUID(), text: String, copiedAt: Date = Date()) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }
}
