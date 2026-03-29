#if DEBUG
import UIKit

extension UIColor {
    /// PhantomSwift design system colors.
    public struct Phantom {
        /// Modern Vibrant Palette
        public static let electricIndigo = UIColor(red: 0.37, green: 0.36, blue: 0.90, alpha: 1.0)
        public static let neonAzure = UIColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0)
        public static let vibrantPurple = UIColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0)
        public static let vibrantGreen = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
        public static let vibrantOrange = UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1.0)
        public static let vibrantRed = UIColor(red: 1.00, green: 0.23, blue: 0.19, alpha: 1.0)
        public static let vibrantTeal = UIColor(red: 0.19, green: 0.69, blue: 0.78, alpha: 1.0)
        public static let vibrantBrown = UIColor(red: 0.64, green: 0.52, blue: 0.37, alpha: 1.0)
        public static let vibrantIndigo = UIColor(red: 0.35, green: 0.34, blue: 0.84, alpha: 1.0)
        public static let vibrantGray = UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1.0)
        public static let vibrantYellow = UIColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0)
        
        /// Glassmorphic Tokens
        public static let glassWhite = UIColor.white.withAlphaComponent(0.12)
        public static let glassBlack = UIColor.black.withAlphaComponent(0.5)
        
        /// Semantic Aliases for backward compatibility
        public static let success = vibrantGreen
        public static let warning = vibrantOrange
        public static let error = vibrantRed
        public static let secondary = vibrantPurple
        
        /// Primary accent color (Phantom Blue)
        public static let primaryColor = electricIndigo
        public static let primary = primaryColor
        
        /// Background color for dark theme
        public static let backgroundDark = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1.0)
        
        /// Background color for light theme
        public static let backgroundLight = UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1.0)
        
        /// Surface color (cards, cells) for dark theme
        public static let surfaceDark = UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)
        
        /// Surface color (cards, cells) for light theme
        public static let surfaceLight = UIColor.white
    }
}
#endif
