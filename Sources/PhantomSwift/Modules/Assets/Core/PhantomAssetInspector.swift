#if DEBUG
import Foundation
import UIKit

/// Metadata for a tracked asset.
public struct PhantomAssetInfo: Identifiable {
    public let id: String
    public let name: String
    public let size: Int64
    public let resolution: String
    public let memoryImpact: String
    public let type: AssetType
    public let path: String
    public let source: SourceType
    public let image: UIImage?
    
    public enum AssetType: String {
        case image = "Image"
        case config = "Config"
        case font = "Font"
        case data = "Data"
    }
    
    public enum SourceType: String {
        case bundle = "BUNDLE"
        case memory = "MEMORY"
    }
}

/// Scans and audits app assets (both on disk and in memory).
public final class PhantomAssetInspector {
    public static let shared = PhantomAssetInspector()
    
    /// Weakly tracks images currently in memory to avoid leaks.
    private let memoryRegistry = NSMapTable<AnyObject, NSString>(keyOptions: .weakMemory, valueOptions: .copyIn)
    
    private init() {
        swizzleUIImage()
    }
    
    /// Registers a live image for auditing.
    internal func trackImage(_ image: UIImage, name: String) {
        memoryRegistry.setObject(name as NSString, forKey: image)
    }
    
    /// Scans the app for resources (Disk + Memory).
    public func scanAssets() -> [PhantomAssetInfo] {
        var results: [PhantomAssetInfo] = []
        
        // 1. Scan Bundle (Files)
        results.append(contentsOf: scanBundle())
        
        // 2. Scan Memory (Dynamic)
        results.append(contentsOf: scanMemory())
        
        return results.sorted(by: { $0.size > $1.size })
    }
    
    private func scanBundle() -> [PhantomAssetInfo] {
        let fileManager = FileManager.default
        guard let bundlePath = Bundle.main.resourcePath else { return [] }
        var results: [PhantomAssetInfo] = []
        let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "webp", "pdf", "json", "plist", "ttf", "otf"]
        
        func scanDirectory(at path: String) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: path)
                for item in contents {
                    let fullPath = (path as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                        if !item.hasSuffix(".app") && !item.hasSuffix(".framework") {
                            scanDirectory(at: fullPath)
                        }
                    } else {
                        let ext = (item as NSString).pathExtension.lowercased()
                        if extensions.contains(ext) {
                            if let info = processFile(at: fullPath) {
                                results.append(info)
                            }
                        }
                    }
                }
            } catch {}
        }
        
        scanDirectory(at: bundlePath)
        return results
    }
    
    private func scanMemory() -> [PhantomAssetInfo] {
        var results: [PhantomAssetInfo] = []
        let enumerator = memoryRegistry.keyEnumerator()
        
        while let image = enumerator.nextObject() as? UIImage {
            let name = memoryRegistry.object(forKey: image) as String? ?? "Unknown Dynamic Image"
            let res = "\(Int(image.size.width))x\(Int(image.size.height))"
            let impactMB = Double(image.size.width * image.size.height * 4 * image.scale * image.scale) / 1024 / 1024
            let size = Int64(impactMB * 1024 * 1024)
            
            results.append(PhantomAssetInfo(
                id: "mem_\(UUID().uuidString)",
                name: name,
                size: size,
                resolution: res,
                memoryImpact: String(format: "%.2f MB", impactMB),
                type: .image,
                path: "In-Memory",
                source: .memory,
                image: image
            ))
        }
        
        return results
    }
    
    private func processFile(at path: String) -> PhantomAssetInfo? {
        let fileManager = FileManager.default
        let fileName = (path as NSString).lastPathComponent
        let ext = (path as NSString).pathExtension.lowercased()
        
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let size = attributes[.size] as? Int64 else { return nil }
        
        var res = "N/A"
        var impact = "N/A"
        var type: PhantomAssetInfo.AssetType = .data
        var image: UIImage? = nil
        
        if ["png", "jpg", "jpeg", "heic", "webp"].contains(ext) {
            type = .image
            if let img = UIImage(contentsOfFile: path) {
                image = img
                res = "\(Int(img.size.width))x\(Int(img.size.height))"
                let impactMB = Double(img.size.width * img.size.height * 4) / 1024 / 1024
                impact = String(format: "%.2f MB", impactMB)
            }
        } else if ["json", "plist"].contains(ext) {
            type = .config
        } else if ["ttf", "otf"].contains(ext) {
            type = .font
        }
        
        return PhantomAssetInfo(
            id: path,
            name: fileName,
            size: size,
            resolution: res,
            memoryImpact: impact,
            type: type,
            path: path,
            source: .bundle,
            image: image
        )
    }
    
    // MARK: - Swizzling
    
    private func swizzleUIImage() {
        let cls = UIImage.self
        
        // Swizzle imageWithData:
        let originalData = class_getClassMethod(cls, #selector(UIImage.init(data:)))
        let swizzledData = class_getClassMethod(cls, #selector(UIImage.phantom_init(data:)))
        if let original = originalData, let swizzled = swizzledData {
            method_exchangeImplementations(original, swizzled)
        }
        
        // Swizzle imageNamed:
        let originalNamed = class_getClassMethod(cls, #selector(UIImage.init(named:)))
        let swizzledNamed = class_getClassMethod(cls, #selector(UIImage.phantom_init(named:)))
        if let original = originalNamed, let swizzled = swizzledNamed {
            method_exchangeImplementations(original, swizzled)
        }
    }
}

// MARK: - UIImage Extension for Swizzling
extension UIImage {
    @objc class func phantom_init(data: Data) -> UIImage? {
        let image = self.phantom_init(data: data) // Calls original
        if let img = image {
            PhantomAssetInspector.shared.trackImage(img, name: "Data Asset (\(data.count / 1024)KB)")
        }
        return image
    }
    
    @objc class func phantom_init(named: String) -> UIImage? {
        let image = self.phantom_init(named: named) // Calls original
        if let img = image {
            PhantomAssetInspector.shared.trackImage(img, name: named)
        }
        return image
    }
}
#endif
