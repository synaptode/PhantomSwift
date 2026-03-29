#if DEBUG
import Foundation
import UserNotifications
import UIKit

// MARK: - PushTemplate

/// A persisted notification template for the Push Simulator.
internal struct PushTemplate: Codable, Identifiable {
    var id: UUID
    var name: String
    var title: String
    var body: String
    var subtitle: String
    var categoryIdentifier: String
    var badge: Int?
    var sound: String          // "default" | "none" | custom filename
    var userInfoJSON: String   // Raw JSON string for custom payload keys
    var delay: TimeInterval    // Seconds before delivery (0 = immediate)

    static var defaultTemplates: [PushTemplate] {
        [
            PushTemplate(
                id: UUID(),
                name: "Simple Alert",
                title: "Hello from PhantomSwift",
                body: "This is a simulated push notification.",
                subtitle: "",
                categoryIdentifier: "",
                badge: nil,
                sound: "default",
                userInfoJSON: "{}",
                delay: 0
            ),
            PushTemplate(
                id: UUID(),
                name: "Order Update",
                title: "Your order is on the way! 🚀",
                body: "Estimated arrival: 15 minutes.",
                subtitle: "Order #1234",
                categoryIdentifier: "",
                badge: 1,
                sound: "default",
                userInfoJSON: "{\"orderId\": \"1234\", \"screen\": \"order_detail\"}",
                delay: 0
            ),
            PushTemplate(
                id: UUID(),
                name: "Silent Push (background fetch)",
                title: "",
                body: "",
                subtitle: "",
                categoryIdentifier: "",
                badge: nil,
                sound: "none",
                userInfoJSON: "{\"content-available\": 1}",
                delay: 0
            ),
            PushTemplate(
                id: UUID(),
                name: "Delayed (5s)",
                title: "Reminder",
                body: "This notification was delayed 5 seconds.",
                subtitle: "",
                categoryIdentifier: "",
                badge: nil,
                sound: "default",
                userInfoJSON: "{}",
                delay: 5
            )
        ]
    }
}

// MARK: - PushSimulatorResult

internal enum PushSimulatorResult {
    case success(identifier: String)
    case permissionDenied
    case error(String)
}

// MARK: - PhantomPushSimulator

/// Delivers local `UNUserNotificationCenter` notifications to simulate APNs pushes.
/// Works entirely on-device without a server or APNs certificate.
///
/// **Permission**: The app must already have notification permission, or this class
/// will request it automatically on first `fire`.
///
/// **Foreground display**: Sets itself as the `UNUserNotificationCenterDelegate` so
/// notifications are shown as banners even while the app is in the foreground.
/// The original delegate (if any) is chained — all its callbacks are forwarded.
///
/// **Limitations**: Content-available (silent) pushes cannot run `application(_:didReceiveRemoteNotification:)`
/// via `UNUserNotificationCenter`. For true BGProcessingTask + silent push integration testing,
/// use the Background Task Inspector module instead.
internal final class PhantomPushSimulator {

    internal static let shared = PhantomPushSimulator()
    private init() {}

    private let storeKey = "com.phantomswift.push.templates"
    private(set) var templates: [PushTemplate] = []

    /// Proxy delegate that allows foreground banner display and forwards to the original delegate.
    private var proxyDelegate: PhantomUNDelegate?

    // MARK: - Lifecycle

    internal func start() {
        loadTemplates()
        installForegroundDelegate()
    }

    private func installForegroundDelegate() {
        let center = UNUserNotificationCenter.current()
        // Don't replace ourselves if already installed
        if center.delegate is PhantomUNDelegate { return }
        let proxy = PhantomUNDelegate(original: center.delegate)
        proxyDelegate = proxy
        center.delegate = proxy
    }

    // MARK: - Template CRUD

    internal func loadTemplates() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let saved = try? JSONDecoder().decode([PushTemplate].self, from: data),
            !saved.isEmpty
        else {
            templates = PushTemplate.defaultTemplates
            saveTemplates()
            return
        }
        templates = saved
    }

    internal func saveTemplates() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    internal func save(_ template: PushTemplate) {
        if let idx = templates.firstIndex(where: { $0.id == template.id }) {
            templates[idx] = template
        } else {
            templates.append(template)
        }
        saveTemplates()
    }

    internal func delete(at offsets: IndexSet) {
        templates = templates.enumerated().compactMap { idx, element in
            offsets.contains(idx) ? nil : element
        }
        saveTemplates()
    }

    // MARK: - Fire

    /// Schedules a local notification mirroring the provided template.
    internal func fire(_ template: PushTemplate, completion: @escaping (PushSimulatorResult) -> Void) {
        installForegroundDelegate()   // idempotent — ensures banners appear in foreground
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self?.schedule(template, center: center, completion: completion)
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    if granted {
                        self?.schedule(template, center: center, completion: completion)
                    } else {
                        DispatchQueue.main.async { completion(.permissionDenied) }
                    }
                }
            default:
                DispatchQueue.main.async { completion(.permissionDenied) }
            }
        }
    }

    private func schedule(
        _ template: PushTemplate,
        center: UNUserNotificationCenter,
        completion: @escaping (PushSimulatorResult) -> Void
    ) {
        let content = UNMutableNotificationContent()

        if !template.title.isEmpty    { content.title    = template.title }
        if !template.subtitle.isEmpty { content.subtitle = template.subtitle }
        if !template.body.isEmpty     { content.body     = template.body }
        if let badge = template.badge { content.badge     = NSNumber(value: badge) }
        if !template.categoryIdentifier.isEmpty {
            content.categoryIdentifier = template.categoryIdentifier
        }

        switch template.sound {
        case "none":    content.sound = nil
        case "default": content.sound = .default
        default:        content.sound = UNNotificationSound(named: UNNotificationSoundName(template.sound))
        }

        // Merge custom userInfo JSON
        if let data = template.userInfoJSON.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] {
            content.userInfo = dict
        }

        let delay = max(0.5, template.delay)  // UNTimeIntervalTrigger requires > 0
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let identifier = "phantom.push.\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    completion(.error(error.localizedDescription))
                } else {
                    completion(.success(identifier: identifier))
                }
            }
        }
    }

    // MARK: - Pending

    internal func getPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests.filter { $0.identifier.hasPrefix("phantom.push.") })
            }
        }
    }

    internal func cancelAll() {
        getPendingNotifications { requests in
            let ids = requests.map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

// MARK: - PhantomUNDelegate
// Allows foreground banner display and chains to the host app's original delegate.

private final class PhantomUNDelegate: NSObject, UNUserNotificationCenterDelegate {

    private weak var original: UNUserNotificationCenterDelegate?

    init(original: UNUserNotificationCenterDelegate?) {
        self.original = original
    }

    // Show banners/sounds/badges even while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if let original = original,
           original.responds(to: #selector(userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            original.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let original = original,
           original.responds(to: #selector(userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            original.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    @available(iOS 12.0, *)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        original?.userNotificationCenter?(center, openSettingsFor: notification)
    }
}

#endif
