#if DEBUG
import Foundation
import UIKit
import UserNotifications

/// Automatic monitor for incoming push notifications (APNs, local, simulated) via UNUserNotificationCenter.
public final class PhantomPushMonitor {
    public static let shared = PhantomPushMonitor()

    private var isStarted = false
    private var proxyDelegate: PhantomPushProxyDelegate?

    private init() {}

    /// Installs swizzling on UNUserNotificationCenter and starts capturing notifications.
    public func start() {
        guard !isStarted else { return }
        isStarted = true

        swizzleNotificationCenterDelegate()
        installProxyOnCurrentCenter()
        hookAppDelegateTokenRegistration()
    }

    private func swizzleNotificationCenterDelegate() {
        let centerCls = UNUserNotificationCenter.self
        let original = #selector(setter: UNUserNotificationCenter.delegate)
        let swizzled = #selector(UNUserNotificationCenter.phantom_setDelegate(_:))
        PhantomSwizzler.swizzle(cls: centerCls, originalSelector: original, swizzledSelector: swizzled)
    }

    private func installProxyOnCurrentCenter() {
        let center = UNUserNotificationCenter.current()
        if !(center.delegate is PhantomPushProxyDelegate) {
            let proxy = PhantomPushProxyDelegate(original: center.delegate)
            proxyDelegate = proxy
            center.delegate = proxy
        }
    }

    private func hookAppDelegateTokenRegistration() {
        DispatchQueue.main.async {
            guard let appDelegate = UIApplication.shared.delegate else { return }
            let delegateClass: AnyClass = type(of: appDelegate)
            let sel = #selector(
                UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
            )
            let swizzledSel = #selector(
                NSObject.phantom_application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
            )

            if class_getInstanceMethod(delegateClass, sel) != nil {
                PhantomSwizzler.swizzle(cls: delegateClass, originalSelector: sel, swizzledSelector: swizzledSel)
            }
        }
    }
}

// MARK: - UNUserNotificationCenter Swizzling

extension UNUserNotificationCenter {
    @objc func phantom_setDelegate(_ delegate: UNUserNotificationCenterDelegate?) {
        if delegate is PhantomPushProxyDelegate {
            phantom_setDelegate(delegate)
            return
        }
        let proxy = PhantomPushProxyDelegate(original: delegate)
        phantom_setDelegate(proxy)
    }
}

// MARK: - AppDelegate Token Hook

extension NSObject {
    @objc func phantom_application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        PhantomPushStore.shared.setDeviceToken(token)

        if responds(to: #selector(phantom_application(_:didRegisterForRemoteNotificationsWithDeviceToken:))) {
            phantom_application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        }
    }
}

// MARK: - Proxy Delegate

internal final class PhantomPushProxyDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var original: UNUserNotificationCenterDelegate?

    init(original: UNUserNotificationCenterDelegate?) {
        self.original = original
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        recordNotification(notification, state: .receivedForeground)

        if let original = original,
           original.responds(to: #selector(userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            original.userNotificationCenter?(
                center,
                willPresent: notification,
                withCompletionHandler: completionHandler
            )
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
        recordNotification(
            response.notification,
            state: .openedByUser,
            actionIdentifier: response.actionIdentifier
        )

        if let original = original,
           original.responds(to: #selector(userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            original.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        openSettingsFor notification: UNNotification?
    ) {
        original?.userNotificationCenter?(center, openSettingsFor: notification)
    }

    private func recordNotification(
        _ notification: UNNotification,
        state: PhantomPushState,
        actionIdentifier: String? = nil
    ) {
        let req = notification.request
        let content = req.content

        let isSim = req.identifier.hasPrefix("phantom.push.")
        let source: PhantomPushSource
        if isSim {
            source = .simulated
        } else if content.userInfo["aps"] != nil {
            source = .remote
        } else {
            source = .local
        }

        var jsonString = "{}"
        if let data = try? JSONSerialization.data(withJSONObject: content.userInfo, options: [.prettyPrinted]),
           let str = String(data: data, encoding: .utf8) {
            jsonString = str
        }

        let record = PhantomPushRecord(
            identifier: req.identifier,
            title: content.title.isEmpty ? "(No Title)" : content.title,
            subtitle: content.subtitle,
            body: content.body,
            badge: content.badge?.intValue,
            sound: content.sound != nil ? "Standard" : nil,
            categoryIdentifier: content.categoryIdentifier,
            userInfoJSON: jsonString,
            timestamp: notification.date,
            source: source,
            state: state,
            actionIdentifier: actionIdentifier
        )

        PhantomPushStore.shared.add(record)
    }
}
#endif
