#if DEBUG
import UIKit

/// Manages themes and color tokens for PhantomSwift UI.
internal final class PhantomTheme {
    public static let shared = PhantomTheme()
    
    public var primaryColor: UIColor { UIColor.Phantom.electricIndigo }
    public var accentColor: UIColor { UIColor.Phantom.vibrantPurple }
    public var cardCornerRadius: CGFloat { 24 }

    /// Niagara design tokens
    /// Pure-black dashboard background for the overlay panel.
    internal var niagaraBackground: UIColor { UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0) }
    /// Row separator at very low opacity — barely visible, just enough for rhythm.
    internal var niagaraSeparator: UIColor { UIColor.white.withAlphaComponent(0.06) }
    /// Standard Niagara list row height.
    internal var niagaraRowHeight: CGFloat { 64 }

    /// Premium Gradient Tokens
    public var primaryGradient: [UIColor] { [primaryColor, UIColor.Phantom.neonAzure] }
    public var secondaryGradient: [UIColor] { [accentColor, UIColor.Phantom.neonAzure] }
    
    internal var currentTheme: PhantomConfig.ThemeType {
        return PhantomSwift.shared.config.theme
    }
    
    /// Returns the appropriate background color for the current theme.
    internal var backgroundColor: UIColor {
        switch currentTheme {
        case .dark: return UIColor.Phantom.backgroundDark
        case .light: return UIColor.Phantom.backgroundLight
        case .auto:
            if #available(iOS 13.0, *) {
                return UIColor { trait -> UIColor in
                    return trait.userInterfaceStyle == .dark ? UIColor.Phantom.backgroundDark : UIColor.Phantom.backgroundLight
                }
            } else {
                return UIColor.Phantom.backgroundDark
            }
        }
    }
    
    /// Returns the appropriate surface color (cells, cards) for the current theme.
    public var surfaceColor: UIColor {
        switch currentTheme {
        case .dark: return UIColor.Phantom.surfaceDark
        case .light: return UIColor.Phantom.surfaceLight
        case .auto:
            if #available(iOS 13.0, *) {
                return UIColor { trait -> UIColor in
                    return trait.userInterfaceStyle == .dark ? UIColor.Phantom.surfaceDark : UIColor.Phantom.surfaceLight
                }
            } else {
                return UIColor.Phantom.surfaceDark
            }
        }
    }
    
    /// Returns the main text color, respecting system appearance for `.auto`.
    internal var textColor: UIColor {
        switch currentTheme {
        case .light: return .black
        case .dark: return .white
        case .auto:
            if #available(iOS 13.0, *) {
                return UIColor { $0.userInterfaceStyle == .dark ? .white : .black }
            }
            return .white
        }
    }
    
    /// Returns the glassmorphic background effect.
    internal var glassEffect: UIBlurEffect {
        if #available(iOS 13.0, *) {
            return currentTheme == .light ? UIBlurEffect(style: .systemUltraThinMaterialLight) : UIBlurEffect(style: .systemUltraThinMaterialDark)
        } else {
            return currentTheme == .light ? UIBlurEffect(style: .extraLight) : UIBlurEffect(style: .dark)
        }
    }
    
    
    /// Background color for dashboard cards.
    public var cardBackgroundColor: UIColor {
        return currentTheme == .light ? .white.withAlphaComponent(0.8) : UIColor.white.withAlphaComponent(0.06)
    }
    
    /// Returns the shadow color for the current theme.
    internal var shadowColor: UIColor {
        return currentTheme == .light ? UIColor.black.withAlphaComponent(0.08) : UIColor.black.withAlphaComponent(0.4)
    }
    
    /// Applies a premium shadow to a layer.
    internal func applyPremiumShadow(to layer: CALayer) {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 15
        layer.shadowOpacity = currentTheme == .light ? 0.12 : 0.6
    }
    
    /// Applies a modern glassmorphic card style to a view.
    public func applyCardStyle(to view: UIView) {
        view.backgroundColor = cardBackgroundColor
        view.layer.cornerRadius = 20
        if #available(iOS 13.0, *) { view.layer.cornerCurve = .continuous }
        view.layer.borderWidth = 1.0
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        applyPremiumShadow(to: view.layer)
    }
}
#endif
