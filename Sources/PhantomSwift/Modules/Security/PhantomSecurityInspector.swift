#if DEBUG
import Foundation
import UIKit
import Security
import MachO

/// Performs security and environment integrity checks.
internal final class PhantomSecurityInspector {
    internal static let shared = PhantomSecurityInspector()

    struct SecurityReport {
        let isJailbroken: Bool
        let isDebuggerAttached: Bool
        let isSimulator: Bool
        let hasScreenRecording: Bool
        let isReverseEngineered: Bool
        let httpsClearTextDetected: Bool

        var score: Int {
            return 100
                - jailbreakDeduction
                - debuggerDeduction
                - simulatorDeduction
                - screenRecordingDeduction
                - reverseEngineeringDeduction
                - clearTextDeduction
        }

        var jailbreakDeduction:          Int { isJailbroken           ? 40 : 0 }
        var debuggerDeduction:           Int { isDebuggerAttached      ? 20 : 0 }
        var simulatorDeduction:          Int { isSimulator             ?  5 : 0 }
        var screenRecordingDeduction:    Int { hasScreenRecording      ? 10 : 0 }
        var reverseEngineeringDeduction: Int { isReverseEngineered     ? 15 : 0 }
        var clearTextDeduction:          Int { httpsClearTextDetected  ? 10 : 0 }

        var statusPhrase: String {
            let s = score
            if s >= 95 { return "Optimal" }
            if s >= 75 { return "Good" }
            if s >= 50 { return "Warning" }
            return "Critical"
        }

        var checks: [SecurityCheck] {
            [
                SecurityCheck(
                    title: "Jailbreak / Root",
                    status: isJailbroken ? "COMPROMISED" : "CLEAN",
                    deduction: jailbreakDeduction,
                    isPassed: !isJailbroken,
                    detail: "Checks for Cydia, bash, apt, substrate and writeable private paths."
                ),
                SecurityCheck(
                    title: "Debugger Attach",
                    status: isDebuggerAttached ? "ATTACHED" : "CLEAN",
                    deduction: debuggerDeduction,
                    isPassed: !isDebuggerAttached,
                    detail: "Reads P_TRACED flag from kernel proc info."
                ),
                SecurityCheck(
                    title: "Screen Recording",
                    status: hasScreenRecording ? "ACTIVE" : "NONE",
                    deduction: screenRecordingDeduction,
                    isPassed: !hasScreenRecording,
                    detail: "UIScreen.isCaptured (iOS 11+). Active recording may expose sensitive data."
                ),
                SecurityCheck(
                    title: "Reverse Engineering",
                    status: isReverseEngineered ? "DETECTED" : "CLEAN",
                    deduction: reverseEngineeringDeduction,
                    isPassed: !isReverseEngineered,
                    detail: "Checks for Frida / Cycript / Substrate injected libraries via dylib enumeration."
                ),
                SecurityCheck(
                    title: "Cleartext HTTP",
                    status: httpsClearTextDetected ? "DETECTED" : "NONE",
                    deduction: clearTextDeduction,
                    isPassed: !httpsClearTextDetected,
                    detail: "Inspects Info.plist NSAppTransportSecurity for NSAllowsArbitraryLoads."
                ),
                SecurityCheck(
                    title: "Runtime Environment",
                    status: isSimulator ? "SIMULATOR" : "HARDWARE",
                    deduction: simulatorDeduction,
                    isPassed: !isSimulator,
                    detail: "Validates hardware-level execution environment via TARGET_OS_SIMULATOR."
                ),
            ]
        }
    }

    struct SecurityCheck {
        let title:     String
        let status:    String
        let deduction: Int
        let isPassed:  Bool
        let detail:    String
    }

    internal func generateReport() -> SecurityReport {
        return SecurityReport(
            isJailbroken:           checkJailbreak(),
            isDebuggerAttached:     checkDebugger(),
            isSimulator:            checkSimulator(),
            hasScreenRecording:     checkScreenRecording(),
            isReverseEngineered:    checkReverseEngineering(),
            httpsClearTextDetected: checkClearText()
        )
    }

    // MARK: - Checks

    private func checkJailbreak() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash", "/bin/sh",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) { return true }
        }
        do {
            let probe = "/private/phantom_jailbreak_probe.txt"
            try "probe".write(toFile: probe, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: probe)
            return true
        } catch { return false }
        #endif
    }

    private func checkDebugger() -> Bool {
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let res = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if res != 0 { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private func checkSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private func checkScreenRecording() -> Bool {
        if #available(iOS 11.0, *) {
            return UIScreen.main.isCaptured
        }
        return false
    }

    private func checkReverseEngineering() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // Check for known reverse engineering / hooking frameworks in loaded dylibs
        let suspects = ["FridaGadget", "frida", "cynject", "libcycript", "MobileSubstrate",
                        "Lobster", "SSLKillSwitch", "A-Bypass"]
        let imageCount = _dyld_image_count()
        for i in 0..<imageCount {
            if let name = _dyld_get_image_name(i) {
                let path = String(cString: name).lowercased()
                if suspects.contains(where: { path.contains($0.lowercased()) }) { return true }
            }
        }
        return false
        #endif
    }

    private func checkClearText() -> Bool {
        guard let ats = Bundle.main.infoDictionary?["NSAppTransportSecurity"] as? [String: Any] else {
            return false
        }
        return ats["NSAllowsArbitraryLoads"] as? Bool ?? false
    }
}
#endif
