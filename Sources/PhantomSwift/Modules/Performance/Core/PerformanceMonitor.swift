#if DEBUG
import UIKit
import MachO

/// Captures real-time performance metrics (FPS, CPU, RAM).
internal final class PerformanceMonitor {
    internal static let shared = PerformanceMonitor()
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: TimeInterval = 0
    private var frameCount: Int = 0
    
    internal var currentFPS: Int = 0
    internal var history: [PerformanceData] = []
    private let maxHistoryCount = 60
    
    internal var onUpdate: ((PerformanceData) -> Void)?
    
    private let queue = DispatchQueue(label: "com.phantomswift.performance", qos: .background)
    private var timer: Timer?
    
    internal func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick(_:)))
        displayLink?.add(to: .main, forMode: .common)
        
        // Move system stats monitoring to background queue to avoid main thread hitches
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.queue.async {
                self?.updateSystemStats()
            }
        }
    }
    
    internal func stop() {
        displayLink?.invalidate()
        timer?.invalidate()
    }
    
    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        
        frameCount += 1
        let delta = link.timestamp - lastTimestamp
        if delta >= 1.0 {
            currentFPS = Int(round(Double(frameCount) / delta))
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
    
    private func updateSystemStats() {
        let cpu = getCPUUsage()
        let ram = getMemoryUsage()
        let data = PerformanceData(fps: currentFPS, cpu: cpu, ram: ram)
        
        self.history.append(data)
        if self.history.count > self.maxHistoryCount {
            self.history.removeFirst()
        }
        
        DispatchQueue.main.async {
            self.onUpdate?(data)
        }
    }
    
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let res = withUnsafeMutablePointer(to: &threadList) {
            return $0.withMemoryRebound(to: thread_act_array_t?.self, capacity: 1) {
                task_threads(mach_task_self_, $0, &threadCount)
            }
        }
        
        if res != KERN_SUCCESS { return 0 }
        
        var totalCPU: Float = 0
        if let threadList = threadList {
            for i in 0..<Int(threadCount) {
                var threadInfo = thread_basic_info()
                var count = mach_msg_type_number_t(THREAD_INFO_MAX)
                let res = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        thread_info(threadList[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                    }
                }
                
                if res == KERN_SUCCESS {
                    if (threadInfo.flags & TH_FLAGS_IDLE) == 0 {
                        totalCPU += Float(threadInfo.cpu_usage) / Float(TH_USAGE_SCALE)
                    }
                }
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadList), vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride))
        }
        
        return Double(totalCPU) * 100.0
    }
    
    private func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? info.resident_size : 0
    }
}

internal struct PerformanceData {
    let fps: Int
    let cpu: Double
    let ram: UInt64
}
#endif
