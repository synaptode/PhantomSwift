#if DEBUG
import Foundation
import UIKit
import Darwin

// MARK: - LayoutConflictEntry

internal struct LayoutConflictEntry: Identifiable {
    let id          = UUID()
    let date        = Date()
    /// The complete raw message block printed by UIKit.
    let message:     String
    /// View class extracted from the "Will attempt to recover" line, if present.
    let viewClass:   String?
    /// Individual constraint description strings.
    let constraints: [String]
    /// Stack frames captured at the moment of detection (approximate — fired on stderr reader thread).
    let callStack:   [String]
}

// MARK: - PhantomLayoutConflictDetector

/// Intercepts Auto Layout conflict messages in real-time by tapping into stderr.
///
/// UIKit prints "Unable to simultaneously satisfy constraints" to stderr whenever
/// a required constraint cannot be satisfied and a breakable one is dropped.
///
/// Implementation:
/// 1. A UNIX pipe is created. `STDERR_FILENO` is redirected to the pipe's write end.
/// 2. The original file descriptor is duplicated so all output is **tee'd** back to
///    Xcode's console — developer experience is unaffected.
/// 3. A background thread reads the pipe, reassembles multi-line conflict blocks,
///    and adds a `LayoutConflictEntry` for each complete block.
///
/// Should be started once, early in the app lifecycle (e.g. in `PhantomSwift.setup()`).
internal final class PhantomLayoutConflictDetector {

    internal static let shared = PhantomLayoutConflictDetector()
    private init() {}

    // MARK: - State

    private let queue     = DispatchQueue(label: "com.phantomswift.layout", attributes: .concurrent)
    private var _entries: [LayoutConflictEntry] = []
    private let maxCount  = 200

    private var _observers: [UUID: () -> Void] = [:]
    private var isStarted  = false

    // Retained FDs
    private var originalStderrFD: Int32 = -1
    private var pipeReadFD:       Int32 = -1

    // MARK: - Public API

    internal var count: Int { queue.sync { _entries.count } }

    internal func getAll() -> [LayoutConflictEntry] {
        queue.sync { _entries.sorted { $0.date > $1.date } }
    }

    internal func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?._entries.removeAll()
        }
        notifyObservers()
    }

    @discardableResult
    internal func addObserver(_ block: @escaping () -> Void) -> UUID {
        let id = UUID()
        queue.async(flags: .barrier) { [weak self] in
            self?._observers[id] = block
        }
        return id
    }

    internal func removeObserver(_ id: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            self?._observers.removeValue(forKey: id)
        }
    }

    // MARK: - Start

    internal func start() {
        guard !isStarted else { return }
        isStarted = true
        installStderrTap()
    }

    // MARK: - Stderr Tap

    private func installStderrTap() {
        var fds = [Int32](repeating: 0, count: 2)
        guard pipe(&fds) == 0 else { return }

        // Preserve original stderr for tee-ing output back to Xcode console.
        originalStderrFD = dup(STDERR_FILENO)
        guard originalStderrFD != -1 else {
            close(fds[0]); close(fds[1]); return
        }

        // Redirect stderr → pipe write end.
        guard dup2(fds[1], STDERR_FILENO) != -1 else {
            close(fds[0]); close(fds[1]); close(originalStderrFD)
            return
        }
        close(fds[1]) // Write end is now owned by STDERR_FILENO.
        pipeReadFD = fds[0]

        let readFD  = pipeReadFD
        let echoFD  = originalStderrFD

        DispatchQueue.global(qos: .background).async { [weak self] in
            let bufSize = 4096
            var buf     = [UInt8](repeating: 0, count: bufSize)
            var lineBuf = ""

            while true {
                let n = read(readFD, &buf, bufSize)
                guard n > 0 else { break }

                // Tee: write every byte back to Xcode's original stderr.
                _ = write(echoFD, buf, n)

                guard let chunk = String(bytes: buf.prefix(n), encoding: .utf8) else { continue }
                lineBuf += chunk

                // Consume complete newline-terminated lines.
                while let nlIdx = lineBuf.firstIndex(of: "\n") {
                    let line = String(lineBuf[lineBuf.startIndex ..< nlIdx])
                    lineBuf  = String(lineBuf[lineBuf.index(after: nlIdx)...])
                    self?.processLine(line)
                }
            }
        }
    }

    // MARK: - Line Parsing State Machine

    private var capturing     = false
    private var captureLines  = [String]()

    /// All lines printed in an Auto Layout conflict block are either:
    /// - indented with spaces / tabs, or
    /// - contain NS/UI class angle-bracket notation ("<NSLayout…>"), or
    /// - are the "Will attempt to recover…" advisory line.
    private let conflictBlockLinePatterns = [
        "NSLayout", "<_UI", "Will attempt", "Make a symbolic breakpoint",
        "constraint ", "(", ")", "<NSAutoresizingMask"
    ]

    private func processLine(_ line: String) {
        if line.contains("Unable to simultaneously satisfy constraints") {
            capturing    = true
            captureLines = [line]
            return
        }

        guard capturing else { return }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let isBlockLine = !trimmed.isEmpty &&
            (line.hasPrefix(" ") || line.hasPrefix("\t") ||
             conflictBlockLinePatterns.contains { line.contains($0) })

        if isBlockLine {
            captureLines.append(line)
        } else {
            // Non-matching line ends the block.
            flushCapturedConflict()
            // If the new line itself starts a new conflict, restart immediately.
            if line.contains("Unable to simultaneously satisfy constraints") {
                capturing    = true
                captureLines = [line]
            }
        }
    }

    private func flushCapturedConflict() {
        guard capturing, !captureLines.isEmpty else { return }
        capturing = false

        let fullMessage = captureLines.joined(separator: "\n")

        // Constraint lines contain angle-bracket class notation.
        let constraints = captureLines.filter {
            $0.contains("NSLayout") || $0.contains("<_UI") || $0.contains("<NSAutoresizing")
        }

        // Extract the involved view class from the "Will attempt to recover" advisory.
        var viewClass: String?
        for line in captureLines where line.contains("Will attempt") || line.contains("breaking constraint") {
            if let extracted = extractViewClass(from: line) {
                viewClass = extracted
                break
            }
        }

        let stack = Thread.callStackSymbols
        let entry = LayoutConflictEntry(
            message: fullMessage,
            viewClass: viewClass,
            constraints: constraints,
            callStack: stack
        )

        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            _entries.insert(entry, at: 0)
            if _entries.count > maxCount { _entries = Array(_entries.prefix(maxCount)) }
        }
        notifyObservers()
        captureLines = []
    }

    private func extractViewClass(from line: String) -> String? {
        guard let ltIdx = line.firstIndex(of: "<") else { return nil }
        let afterLt = line[line.index(after: ltIdx)...]

        if let spIdx = afterLt.firstIndex(of: ":") {
            return String(afterLt[..<spIdx])
        } else if let gtIdx = afterLt.firstIndex(of: ">") {
            return String(afterLt[..<gtIdx])
        }
        return nil
    }

    // MARK: - Observer Notification

    private func notifyObservers() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let blocks = self.queue.sync { self._observers.values.map { $0 } }
            blocks.forEach { $0() }
        }
    }
}
#endif
