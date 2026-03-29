#if DEBUG
import Foundation

/// Defines the operating environment for PhantomSwift.
public enum PhantomEnvironment: Equatable {
    /// Full development mode: All features enabled.
    case dev
    /// User Acceptance Testing mode: Essential monitoring and reporting tools.
    case uat
    /// Release mode: No footprint in production (safely disabled).
    case release
    /// Staging mode: Full features with slightly different config (simulation).
    case staging
    /// Custom set of enabled features.
    case custom([PhantomFeature])

    /// Returns the set of features enabled for the current environment.
    public var enabledFeatures: Set<PhantomFeature> {
        switch self {
        case .dev, .staging:
            return Set(PhantomFeature.allCases)
        case .uat:
            return [.network, .interceptor, .logger, .qa]
        case .release:
            return []
        case .custom(let features):
            return Set(features)
        }
    }
    
    /// Returns a human-readable name for the environment.
    public var name: String {
        switch self {
        case .dev: return "Development"
        case .uat: return "User testing"
        case .release: return "Production"
        case .staging: return "Staging"
        case .custom: return "Custom"
        }
    }
}
#endif
