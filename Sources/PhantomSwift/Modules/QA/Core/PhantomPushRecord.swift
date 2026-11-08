#if DEBUG
import Foundation

/// Origin source of a push or local notification.
public enum PhantomPushSource: String, Codable {
    case remote = "Remote"
    case local = "Local"
    case simulated = "Simulated"
}

/// Delivery or user interaction lifecycle state for a notification.
public enum PhantomPushState: String, Codable {
    case receivedForeground = "Foreground"
    case openedByUser = "Opened"
    case background = "Background"
}

/// Captured notification payload, metadata, and lifecycle status.
public struct PhantomPushRecord: Identifiable, Codable {
    public let id: UUID
    public let identifier: String
    public let title: String
    public let subtitle: String
    public let body: String
    public let badge: Int?
    public let sound: String?
    public let categoryIdentifier: String
    public let userInfoJSON: String
    public let timestamp: Date
    public let source: PhantomPushSource
    public var state: PhantomPushState
    public var actionIdentifier: String?

    public init(
        id: UUID = UUID(),
        identifier: String,
        title: String,
        subtitle: String = "",
        body: String,
        badge: Int? = nil,
        sound: String? = nil,
        categoryIdentifier: String = "",
        userInfoJSON: String = "{}",
        timestamp: Date = Date(),
        source: PhantomPushSource = .remote,
        state: PhantomPushState = .receivedForeground,
        actionIdentifier: String? = nil
    ) {
        self.id = id
        self.identifier = identifier
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.badge = badge
        self.sound = sound
        self.categoryIdentifier = categoryIdentifier
        self.userInfoJSON = userInfoJSON
        self.timestamp = timestamp
        self.source = source
        self.state = state
        self.actionIdentifier = actionIdentifier
    }
}
#endif
