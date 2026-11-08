#if DEBUG
import Foundation
#if canImport(WebKit)
import WebKit

/// Manages cookies and website data records for WKWebView.
public final class PhantomWebViewStorageManager {
    public static let shared = PhantomWebViewStorageManager()

    private init() {}

    /// Fetches all cookies from WKHTTPCookieStore.
    public func fetchCookies(completion: @escaping ([HTTPCookie]) -> Void) {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        cookieStore.getAllCookies { cookies in
            DispatchQueue.main.async {
                completion(cookies.sorted { $0.domain < $1.domain })
            }
        }
    }

    /// Deletes a specific cookie.
    public func deleteCookie(_ cookie: HTTPCookie, completion: @escaping () -> Void) {
        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        cookieStore.delete(cookie) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    /// Clears all cookies from WKHTTPCookieStore.
    public func clearAllCookies(completion: @escaping () -> Void) {
        fetchCookies { cookies in
            guard !cookies.isEmpty else {
                completion()
                return
            }
            let group = DispatchGroup()
            let cookieStore = WKWebsiteDataStore.default().httpCookieStore
            for cookie in cookies {
                group.enter()
                cookieStore.delete(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                completion()
            }
        }
    }

    /// Fetches all website data records (localStorage, IndexedDB, Cache, etc.).
    public func fetchWebsiteDataRecords(completion: @escaping ([WKWebsiteDataRecord]) -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.fetchDataRecords(ofTypes: types) { records in
            DispatchQueue.main.async {
                completion(records.sorted { $0.displayName < $1.displayName })
            }
        }
    }

    /// Removes a specific website data record.
    public func removeWebsiteDataRecord(_ record: WKWebsiteDataRecord, completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: record.dataTypes, for: [record]) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    /// Clears all website data across all types and domains.
    public func clearAllWebsiteData(completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: types, modifiedSince: dateFrom) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
#endif
#endif
