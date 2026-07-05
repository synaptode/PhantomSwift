#if DEBUG
import Foundation

internal enum PhantomPluginRegistry {
    static func merged(existing: [PhantomPlugin], inserting plugin: PhantomPlugin) -> [PhantomPlugin] {
        var result = existing.filter { $0.identifier != plugin.identifier }
        result.append(plugin)
        return result
    }
}
#endif
