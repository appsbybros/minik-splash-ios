import Foundation

/// Completion identities are separate from utterance text: repeated words and
/// late callbacks from an interrupted prompt cannot complete a newer queue.
struct LearningSpeechQueueState: Sendable {
    private(set) var pending: Set<ObjectIdentifier> = []

    mutating func enqueue(_ id: ObjectIdentifier) { pending.insert(id) }
    mutating func cancelAll() { pending.removeAll() }

    /// Returns true only when this callback completes the active queue.
    mutating func finish(_ id: ObjectIdentifier) -> Bool {
        guard pending.remove(id) != nil else { return false }
        return pending.isEmpty
    }
}
