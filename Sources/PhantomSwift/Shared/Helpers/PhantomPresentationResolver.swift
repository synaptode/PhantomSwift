#if DEBUG
import UIKit

/// Centralized resolution for host app windows and presenters.
internal enum PhantomPresentationResolver {
    @available(iOS 13.0, *)
    private static func candidateScenes() -> [UIWindowScene] {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { lhs, rhs in
                activationRank(lhs.activationState) < activationRank(rhs.activationState)
            }
    }

    @available(iOS 13.0, *)
    private static func activationRank(_ state: UIScene.ActivationState) -> Int {
        switch state {
        case .foregroundActive: return 0
        case .foregroundInactive: return 1
        case .background: return 2
        case .unattached: return 3
        @unknown default: return 4
        }
    }

    static func hostWindows() -> [UIWindow] {
        if #available(iOS 13.0, *) {
            let sceneWindows = candidateScenes().flatMap(\.windows)
            let filtered = sceneWindows.filter { !($0 is PhantomHUDWindow) }
            if !filtered.isEmpty {
                return filtered
            }
        }

        return UIApplication.shared.windows.filter { !($0 is PhantomHUDWindow) }
    }

    static func activeHostWindow() -> UIWindow? {
        let windows = hostWindows()
        return windows.first(where: \.isKeyWindow)
            ?? windows.first(where: { $0.rootViewController != nil })
            ?? windows.first
    }

    static func activeHostWindowRequiringRoot() -> UIWindow? {
        hostWindows().first(where: { $0.isKeyWindow && $0.rootViewController != nil })
            ?? hostWindows().first(where: { $0.rootViewController != nil })
    }

    static func topPresenter() -> UIViewController? {
        guard let root = activeHostWindowRequiringRoot()?.rootViewController else { return nil }

        var presenter: UIViewController = root
        var depth = 0
        while let next = presenter.presentedViewController, depth < 16 {
            presenter = next
            depth += 1
        }
        return presenter
    }

    static func inspectedRootView(fallback: UIView? = nil) -> UIView {
        activeHostWindow() ?? fallback ?? UIView(frame: UIScreen.main.bounds)
    }

    static func topSafeAreaInset(fallback: CGFloat = 44) -> CGFloat {
        activeHostWindow()?.safeAreaInsets.top ?? fallback
    }
}
#endif
