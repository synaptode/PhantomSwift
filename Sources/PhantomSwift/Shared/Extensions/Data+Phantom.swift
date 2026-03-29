#if DEBUG
import Foundation

extension Data {
    /// Returns a pretty-printed JSON string if possible.
    var prettyJSON: String? {
        guard let json = try? JSONSerialization.jsonObject(with: self, options: .mutableContainers),
              let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return String(data: self, encoding: .utf8)
        }
        return String(data: jsonData, encoding: .utf8)
    }
}
#endif
