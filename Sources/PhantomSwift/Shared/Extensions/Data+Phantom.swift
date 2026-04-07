#if DEBUG
import Foundation

extension Data {
    /// Returns a pretty-printed JSON string if possible.
    var prettyJSON: String? {
        do {
            let json = try JSONSerialization.jsonObject(with: self, options: [])
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            return String(data: self, encoding: .utf8)
        }
    }
}
#endif
