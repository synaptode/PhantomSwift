#if DEBUG
import UIKit

/// Monitor for system states like Battery and Thermal.
public final class PhantomEnvironmentMonitor {
    public static let shared = PhantomEnvironmentMonitor()
    
    private var simulatedBatteryLevel: Float? {
        didSet { UserDefaults.standard.set(simulatedBatteryLevel, forKey: "PhantomSimulatedBattery") }
    }
    private var simulatedThermalState: ProcessInfo.ThermalState? {
        didSet { 
            if let state = simulatedThermalState {
                UserDefaults.standard.set(state.rawValue, forKey: "PhantomSimulatedThermal")
            } else {
                UserDefaults.standard.removeObject(forKey: "PhantomSimulatedThermal")
            }
        }
    }
    
    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UserDefaults.standard.object(forKey: "PhantomSimulatedBattery") != nil {
            self.simulatedBatteryLevel = UserDefaults.standard.float(forKey: "PhantomSimulatedBattery")
        }
        if let thermalRaw = UserDefaults.standard.object(forKey: "PhantomSimulatedThermal") as? Int {
            self.simulatedThermalState = ProcessInfo.ThermalState(rawValue: thermalRaw)
        }
    }
    
    public var batteryLevel: Float {
        return simulatedBatteryLevel ?? UIDevice.current.batteryLevel
    }
    
    public var batteryState: UIDevice.BatteryState {
        return UIDevice.current.batteryState
    }
    
    public var thermalState: ProcessInfo.ThermalState {
        return simulatedThermalState ?? ProcessInfo.processInfo.thermalState
    }
    
    // MARK: - Advanced Telemetry
    
    public var freeDiskSpace: Int64 {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return 0 }
        let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: path)
        return (systemAttributes?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
    }
    
    public var totalDiskSpace: Int64 {
        guard let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return 0 }
        let systemAttributes = try? FileManager.default.attributesOfFileSystem(forPath: path)
        return (systemAttributes?[.systemSize] as? NSNumber)?.int64Value ?? 0
    }
    
    public var usedMemory: UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return kerr == KERN_SUCCESS ? taskInfo.resident_size : 0
    }
    
    public func setSimulatedBatteryLevel(_ level: Float?) {
        self.simulatedBatteryLevel = level
        NotificationCenter.default.post(name: .phantomSystemStateChanged, object: nil)
    }
    
    public func setSimulatedThermalState(_ state: ProcessInfo.ThermalState?) {
        self.simulatedThermalState = state
        NotificationCenter.default.post(name: .phantomSystemStateChanged, object: nil)
    }
}
#endif
