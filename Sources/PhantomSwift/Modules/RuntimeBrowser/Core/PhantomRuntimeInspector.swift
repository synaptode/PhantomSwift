#if DEBUG
import Foundation
import ObjectiveC

// MARK: - Data Models

/// Metadata about an Objective-C method captured from the runtime.
internal struct PhantomMethodInfo {
    let name: String
    let encoding: String
    let isClassMethod: Bool
    let returnType: String
    let argumentTypes: [String]

    var displaySignature: String {
        let prefix = isClassMethod ? "+" : "-"
        if argumentTypes.isEmpty {
            return "\(prefix) (\(returnType))\(name)"
        }
        let parts = name.components(separatedBy: ":")
        var sig = "\(prefix) (\(returnType))"
        for (i, part) in parts.enumerated() where !part.isEmpty {
            let argType = i < argumentTypes.count ? argumentTypes[i] : "id"
            if i == 0 {
                sig += "\(part):(\(argType))arg\(i)"
            } else {
                sig += " \(part):(\(argType))arg\(i)"
            }
        }
        return sig
    }
}

/// Metadata about an Objective-C property captured from the runtime.
internal struct PhantomPropertyInfo {
    let name: String
    let attributes: String
    let isReadOnly: Bool
    let type: String
}

/// Metadata about an instance variable captured from the runtime.
internal struct PhantomIvarInfo {
    let name: String
    let type: String
    let offset: Int
}

/// Full snapshot of an Objective-C class captured from the runtime.
internal struct PhantomClassInfo {
    let name: String
    let superclassName: String?
    let methods: [PhantomMethodInfo]
    let properties: [PhantomPropertyInfo]
    let ivars: [PhantomIvarInfo]
    let protocols: [String]
    let instanceSize: Int
}

// MARK: - Inspector

/// Provides read-only introspection of the Objective-C runtime.
/// Thread-safe via concurrent queue + barrier for cache writes.
internal final class PhantomRuntimeInspector {

    internal static let shared = PhantomRuntimeInspector()
    private init() {}

    private let queue = DispatchQueue(label: "com.phantom.runtimeinspector", attributes: .concurrent)
    private var _cache: [String: PhantomClassInfo] = [:]

    // MARK: - All Class Names

    /// Returns all loaded Objective-C class names, optionally filtered.
    ///
    /// Uses `objc_copyClassNamesForImage` per dyld image instead of `objc_copyClassList`.
    /// Enumerates loaded class names via `Bundle` image paths + `objc_copyClassNamesForImage`.
    /// This avoids touching raw `AnyClass` pointers, which can trigger lazy class realization
    /// on unrealized Swift classes — causing `NSMapGet(NULL)` crashes and spurious
    /// `+initialize` side effects (e.g. UIColor out-of-range warnings).
    internal func allClassNames(filter: String = "") -> [String] {
        let lowerFilter = filter.lowercased()
        var names = Set<String>()

        let images = Bundle.allBundles + Bundle.allFrameworks
        for bundle in images {
            guard let executablePath = bundle.executablePath else { continue }
            var classCount: UInt32 = 0
            guard let classNameList = executablePath.withCString({ path in
                objc_copyClassNamesForImage(path, &classCount)
            }), classCount > 0 else { continue }
            defer { free(UnsafeMutableRawPointer(mutating: classNameList)) }

            for j in 0..<Int(classCount) {
                let name = String(cString: classNameList[j])
                if filter.isEmpty || name.lowercased().contains(lowerFilter) {
                    names.insert(name)
                }
            }
        }
        return names.sorted()
    }

    /// Returns detailed info about a specific class by name, using an in-memory cache.
    internal func classInfo(for className: String) -> PhantomClassInfo? {
        // Fast path — read from cache
        var cached: PhantomClassInfo?
        queue.sync { cached = self._cache[className] }
        if let cached { return cached }

        guard let cls = NSClassFromString(className) else { return nil }
        let info = buildClassInfo(cls, name: className)

        // Cache write via barrier
        queue.async(flags: .barrier) { [weak self] in
            self?._cache[className] = info
        }
        return info
    }

    /// Clears the internal class info cache.
    internal func clearCache() {
        queue.async(flags: .barrier) { [weak self] in
            self?._cache.removeAll()
        }
    }

    // MARK: - Private Builder

    private func buildClassInfo(_ cls: AnyClass, name: String) -> PhantomClassInfo {
        let superName = class_getSuperclass(cls).map { String(cString: class_getName($0)) }
        let instanceSize = class_getInstanceSize(cls)

        return PhantomClassInfo(
            name: name,
            superclassName: superName,
            methods: extractMethods(from: cls),
            properties: extractProperties(from: cls),
            ivars: extractIvars(from: cls),
            protocols: extractProtocols(from: cls),
            instanceSize: instanceSize
        )
    }

    // MARK: - Methods

    private func extractMethods(from cls: AnyClass) -> [PhantomMethodInfo] {
        var result: [PhantomMethodInfo] = []

        // Instance methods
        result += copyMethods(from: cls, isClassMethod: false)

        // Class methods via meta-class
        if let meta = object_getClass(cls) {
            result += copyMethods(from: meta, isClassMethod: true)
        }

        return result.sorted { $0.name < $1.name }
    }

    private func copyMethods(from cls: AnyClass, isClassMethod: Bool) -> [PhantomMethodInfo] {
        var count: UInt32 = 0
        guard let list = class_copyMethodList(cls, &count) else { return [] }
        defer { free(list) }

        var result: [PhantomMethodInfo] = []
        for i in 0..<Int(count) {
            let method = list[i]
            let sel = method_getName(method)
            let name = String(cString: sel_getName(sel))
            let encoding: String
            if let enc = method_getTypeEncoding(method) {
                encoding = String(cString: enc)
            } else {
                encoding = "?"
            }

            let returnTypePtr = method_copyReturnType(method)
            let returnType = ObjCTypeDecoder.decode(returnTypePtr)
            free(returnTypePtr)

            var argTypes: [String] = []
            let argCount = method_getNumberOfArguments(method)
            // Skip index 0 (self) and 1 (_cmd)
            for j in UInt32(2)..<argCount {
                let argPtr = method_copyArgumentType(method, j)
                argTypes.append(ObjCTypeDecoder.decode(argPtr))
                free(argPtr)
            }

            result.append(PhantomMethodInfo(
                name: name,
                encoding: encoding,
                isClassMethod: isClassMethod,
                returnType: returnType,
                argumentTypes: argTypes
            ))
        }
        return result
    }

    // MARK: - Properties

    private func extractProperties(from cls: AnyClass) -> [PhantomPropertyInfo] {
        var count: UInt32 = 0
        guard let list = class_copyPropertyList(cls, &count) else { return [] }
        defer { free(list) }

        var result: [PhantomPropertyInfo] = []
        for i in 0..<Int(count) {
            let prop = list[i]
            let name = String(cString: property_getName(prop))
            let attrString = property_getAttributes(prop).map { String(cString: $0) } ?? ""
            let isReadOnly = attrString.contains(",R,") || attrString.hasSuffix(",R") || attrString.hasPrefix("R,")
            let type = ObjCTypeDecoder.decodePropertyAttributes(attrString)
            result.append(PhantomPropertyInfo(name: name, attributes: attrString, isReadOnly: isReadOnly, type: type))
        }
        return result.sorted { $0.name < $1.name }
    }

    // MARK: - Ivars

    private func extractIvars(from cls: AnyClass) -> [PhantomIvarInfo] {
        var count: UInt32 = 0
        guard let list = class_copyIvarList(cls, &count) else { return [] }
        defer { free(list) }

        var result: [PhantomIvarInfo] = []
        for i in 0..<Int(count) {
            let ivar = list[i]
            let name = ivar_getName(ivar).map { String(cString: $0) } ?? "<unnamed>"
            let type = ivar_getTypeEncoding(ivar).map { ObjCTypeDecoder.decode($0) } ?? "?"
            let offset = Int(ivar_getOffset(ivar))
            result.append(PhantomIvarInfo(name: name, type: type, offset: offset))
        }
        return result
    }

    // MARK: - Protocols

    private func extractProtocols(from cls: AnyClass) -> [String] {
        var count: UInt32 = 0
        guard let list = class_copyProtocolList(cls, &count) else { return [] }
        defer { free(UnsafeMutableRawPointer(mutating: list)) }

        var result: [String] = []
        for i in 0..<Int(count) {
            result.append(String(cString: protocol_getName(list[i])))
        }
        return result.sorted()
    }
}

// MARK: - ObjC Type Decoder

/// Decodes Objective-C runtime type encoding strings into human-readable Swift/ObjC types.
internal enum ObjCTypeDecoder {

    internal static func decode(_ rawPtr: UnsafePointer<CChar>?) -> String {
        guard let p = rawPtr else { return "?" }
        return decodeRaw(String(cString: p))
    }

    internal static func decodeRaw(_ raw: String) -> String {
        // Strip leading/trailing qualifiers (r, n, N, o, O, R, V)
        var s = raw.trimmingCharacters(in: CharacterSet(charactersIn: "rnNoORV"))

        switch s {
        case "c":  return "char"
        case "i":  return "int"
        case "s":  return "short"
        case "l":  return "long"
        case "q":  return "long long"
        case "C":  return "unsigned char"
        case "I":  return "unsigned int"
        case "S":  return "unsigned short"
        case "L":  return "unsigned long"
        case "Q":  return "unsigned long long"
        case "f":  return "float"
        case "d":  return "double"
        case "D":  return "long double"
        case "B":  return "BOOL"
        case "v":  return "void"
        case "*":  return "char *"
        case "@":  return "id"
        case "#":  return "Class"
        case ":":  return "SEL"
        case "?":  return "IMP"
        default:   break
        }

        // Named object: @"ClassName"
        if s.hasPrefix("@\"") && s.hasSuffix("\"") {
            let inner = s.dropFirst(2).dropLast()
            return "\(inner) *"
        }

        // Pointer: ^type
        if s.hasPrefix("^") {
            s = String(s.dropFirst())
            return "\(decodeRaw(s)) *"
        }

        // Struct: {name=...}
        if s.hasPrefix("{") {
            if let eqIdx = s.firstIndex(of: "=") {
                let structName = s[s.index(after: s.startIndex)..<eqIdx]
                return "struct \(structName)"
            }
            return "struct"
        }

        // Array: [count type]
        if s.hasPrefix("[") {
            return "array"
        }

        // Union: (name=...)
        if s.hasPrefix("(") {
            if let eqIdx = s.firstIndex(of: "=") {
                let unionName = s[s.index(after: s.startIndex)..<eqIdx]
                return "union \(unionName)"
            }
            return "union"
        }

        // Bitfield: bN
        if s.hasPrefix("b"), let _ = Int(s.dropFirst()) {
            return "bitfield(\(s.dropFirst()))"
        }

        return raw
    }

    /// Decodes the type from a property attribute string (e.g. "T@\"NSString\",&,N,V_name").
    internal static func decodePropertyAttributes(_ attrs: String) -> String {
        // Format: T<typeEncoding>,<attributes>
        guard attrs.hasPrefix("T") else { return "?" }
        var rest = String(attrs.dropFirst())                  // drop leading "T"
        if let commaIdx = rest.firstIndex(of: ",") {
            rest = String(rest[..<commaIdx])
        }
        return decodeRaw(rest)
    }
}
#endif
