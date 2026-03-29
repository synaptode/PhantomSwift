#if DEBUG
import Foundation
import MetricKit

// MARK: - PhantomMetricPayload

/// Snapshot of the most recent MetricKit delivery.
internal struct PhantomMetricPayload {
    let receivedAt: Date
    let appVersion: String

    // Launch
    let timeToFirstDraw: Double?          // ms — histogrammed median
    let applicationResumeTime: Double?    // ms

    // Responsiveness
    let hangDuration: Double?             // ms cumulative

    // CPU
    let cpuTime: Double?                  // s
    let cumulativeCPUInstructions: Double? // count

    // Memory
    let peakMemoryUsage: Double?          // bytes
    let averageSuspendedMemory: Double?   // bytes

    // Disk
    let cumulativeLogicalWrites: Double?  // bytes
}

// MARK: - PhantomDiagnosticPayload

internal struct PhantomDiagnosticPayload {
    let receivedAt: Date
    let crashCount: Int
    let hangCount: Int
    let cpuExceptionCount: Int
    let diskWriteExceptionCount: Int
}

// MARK: - PhantomMetricKitMonitor

/// Subscribes to MetricKit (iOS 13+) and surfaces diagnostic + performance
/// payloads inside the PhantomSwift Performance dashboard.
///
/// MetricKit delivers payloads at most once per day (24h window). In development,
/// Xcode may deliver a payload shortly after installation for testing.
@available(iOS 13.0, *)
internal final class PhantomMetricKitMonitor: NSObject, MXMetricManagerSubscriber {

    internal static let shared = PhantomMetricKitMonitor()
    private override init() { super.init() }

    // MARK: - State

    private(set) var latestMetric: PhantomMetricPayload?
    private(set) var latestDiagnostic: PhantomDiagnosticPayload?

    /// Observers notified on main thread when new payloads arrive.
    private var observers: [() -> Void] = []

    // MARK: - Lifecycle

    internal func start() {
        MXMetricManager.shared.add(self)
    }

    internal func stop() {
        MXMetricManager.shared.remove(self)
    }

    internal func addObserver(_ block: @escaping () -> Void) {
        observers.append(block)
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard let payload = payloads.last else { return }

        let version = "\(payload.latestApplicationVersion)"
        var p = PhantomMetricPayload(
            receivedAt: Date(),
            appVersion: version,
            timeToFirstDraw: nil,
            applicationResumeTime: nil,
            hangDuration: nil,
            cpuTime: nil,
            cumulativeCPUInstructions: nil,
            peakMemoryUsage: nil,
            averageSuspendedMemory: nil,
            cumulativeLogicalWrites: nil
        )

        // Launch metrics
        if let launch = payload.applicationLaunchMetrics {
            p = PhantomMetricPayload(
                receivedAt: p.receivedAt,
                appVersion: p.appVersion,
                timeToFirstDraw: medianMs(launch.histogrammedTimeToFirstDraw),
                applicationResumeTime: medianMs(launch.histogrammedApplicationResumeTime),
                hangDuration: p.hangDuration,
                cpuTime: p.cpuTime,
                cumulativeCPUInstructions: p.cumulativeCPUInstructions,
                peakMemoryUsage: p.peakMemoryUsage,
                averageSuspendedMemory: p.averageSuspendedMemory,
                cumulativeLogicalWrites: p.cumulativeLogicalWrites
            )
        }

        // Responsiveness
        if let responsiveness = payload.applicationResponsivenessMetrics {
            p = PhantomMetricPayload(
                receivedAt: p.receivedAt,
                appVersion: p.appVersion,
                timeToFirstDraw: p.timeToFirstDraw,
                applicationResumeTime: p.applicationResumeTime,
                hangDuration: totalMs(responsiveness.histogrammedApplicationHangTime),
                cpuTime: p.cpuTime,
                cumulativeCPUInstructions: p.cumulativeCPUInstructions,
                peakMemoryUsage: p.peakMemoryUsage,
                averageSuspendedMemory: p.averageSuspendedMemory,
                cumulativeLogicalWrites: p.cumulativeLogicalWrites
            )
        }

        // CPU
        if let cpu = payload.cpuMetrics {
            p = PhantomMetricPayload(
                receivedAt: p.receivedAt,
                appVersion: p.appVersion,
                timeToFirstDraw: p.timeToFirstDraw,
                applicationResumeTime: p.applicationResumeTime,
                hangDuration: p.hangDuration,
                cpuTime: cpu.cumulativeCPUTime.converted(to: .seconds).value,
                cumulativeCPUInstructions: payload.cpuMetrics != nil
                    ? nil  // No direct accessor for instruction count in public API
                    : nil,
                peakMemoryUsage: p.peakMemoryUsage,
                averageSuspendedMemory: p.averageSuspendedMemory,
                cumulativeLogicalWrites: p.cumulativeLogicalWrites
            )
        }

        // Memory
        if let memory = payload.memoryMetrics {
            p = PhantomMetricPayload(
                receivedAt: p.receivedAt,
                appVersion: p.appVersion,
                timeToFirstDraw: p.timeToFirstDraw,
                applicationResumeTime: p.applicationResumeTime,
                hangDuration: p.hangDuration,
                cpuTime: p.cpuTime,
                cumulativeCPUInstructions: p.cumulativeCPUInstructions,
                peakMemoryUsage: memory.peakMemoryUsage.converted(to: .bytes).value,
                averageSuspendedMemory: 0,
                cumulativeLogicalWrites: p.cumulativeLogicalWrites
            )
        }

        // Disk
        if let disk = payload.diskIOMetrics {
            p = PhantomMetricPayload(
                receivedAt: p.receivedAt,
                appVersion: p.appVersion,
                timeToFirstDraw: p.timeToFirstDraw,
                applicationResumeTime: p.applicationResumeTime,
                hangDuration: p.hangDuration,
                cpuTime: p.cpuTime,
                cumulativeCPUInstructions: p.cumulativeCPUInstructions,
                peakMemoryUsage: p.peakMemoryUsage,
                averageSuspendedMemory: p.averageSuspendedMemory,
                cumulativeLogicalWrites: disk.cumulativeLogicalWrites.converted(to: .bytes).value
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.latestMetric = p
            self?.observers.forEach { $0() }
        }
    }

    @available(iOS 14.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let payload = payloads.last else { return }

        let d = PhantomDiagnosticPayload(
            receivedAt: Date(),
            crashCount: payload.crashDiagnostics?.count ?? 0,
            hangCount: payload.hangDiagnostics?.count ?? 0,
            cpuExceptionCount: payload.cpuExceptionDiagnostics?.count ?? 0,
            diskWriteExceptionCount: payload.diskWriteExceptionDiagnostics?.count ?? 0
        )

        // Forward crash diagnostics to the Crash Log Store.
        if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
            PhantomCrashLogStore.shared.ingestCrashDiagnostics(crashes)
        }

        DispatchQueue.main.async { [weak self] in
            self?.latestDiagnostic = d
            self?.observers.forEach { $0() }
        }
    }

    // MARK: - Histogram helpers

    private func medianMs<UnitType: Dimension>(
        _ histogram: MXHistogram<UnitType>
    ) -> Double? {
        // Sum all bucket counts to find total samples
        var totalCount = 0
        var buckets: [(start: Double, count: Int)] = []

        let enumerator = histogram.bucketEnumerator
        while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitType> {
            let ms = bucket.bucketStart.converted(to: UnitType.baseUnit()).value * 1000
            let cnt = bucket.bucketCount
            buckets.append((ms, cnt))
            totalCount += cnt
        }

        guard totalCount > 0 else { return nil }

        // Find median bucket
        let medianIdx = totalCount / 2
        var accumulated = 0
        for bucket in buckets {
            accumulated += bucket.count
            if accumulated >= medianIdx {
                return bucket.start
            }
        }
        return buckets.last?.start
    }

    private func totalMs<UnitType: Dimension>(
        _ histogram: MXHistogram<UnitType>
    ) -> Double? {
        var total: Double = 0
        var hasData = false

        let enumerator = histogram.bucketEnumerator
        while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitType> {
            let ms = bucket.bucketStart.converted(to: UnitType.baseUnit()).value * 1000
            total += ms * Double(bucket.bucketCount)
            hasData = true
        }

        return hasData ? total : nil
    }
}
#endif
