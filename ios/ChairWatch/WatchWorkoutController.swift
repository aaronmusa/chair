//
//  WatchWorkoutController.swift
//  ChairWatch
//
//  Created by Aaron Musa on 11/3/26.
//

import HealthKit
import Observation
import WatchKit

import ChairKit

@MainActor
@Observable
final class WatchWorkoutController: NSObject, WatchKeepAlive {
    static let fallbackNotice = "Health is off · screen may sleep"

    private(set) var isRunning = false
    private(set) var heartRate: Int?
    private(set) var notice: String?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private var session: HKWorkoutSession?
    @ObservationIgnored private var builder: HKLiveWorkoutBuilder?
    @ObservationIgnored private var runtime: WKExtendedRuntimeSession?

    func start() async {
        guard !isRunning else { return }
        isRunning = true
        do {
            try await authorize()
            try await startWorkout()
            notice = nil
        } catch {
            startFallback()
        }
    }

    func end() {
        guard isRunning else { return }
        isRunning = false
        heartRate = nil
        runtime?.invalidate()
        runtime = nil
        guard let session, let builder else { return }
        session.end()
        self.session = nil
        self.builder = nil
        Task { await finish(builder) }
    }

    private func authorize() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HKError(.errorHealthDataUnavailable) }
        let heartRate = HKQuantityType(.heartRate)
        try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [heartRate])
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else {
            throw HKError(.errorAuthorizationDenied)
        }
    }

    private func startWorkout() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .tennis
        configuration.locationType = .outdoor
        let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
        builder.delegate = self
        self.session = session
        self.builder = builder
        let started = Date()
        session.startActivity(with: started)
        try await builder.beginCollection(at: started)
    }

    private func finish(_ builder: HKLiveWorkoutBuilder) async {
        try? await builder.endCollection(at: Date())
        _ = try? await builder.finishWorkout()
    }

    private func startFallback() {
        notice = Self.fallbackNotice
        let runtime = WKExtendedRuntimeSession()
        runtime.start()
        self.runtime = runtime
    }

    private func updateHeartRate(_ beatsPerMinute: Double?) {
        heartRate = beatsPerMinute.map { Int($0.rounded()) }
    }
}

extension WatchWorkoutController: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let heartRate = HKQuantityType(.heartRate)
        guard collectedTypes.contains(heartRate) else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let beatsPerMinute = workoutBuilder.statistics(for: heartRate)?.mostRecentQuantity()?.doubleValue(for: unit)
        Task { @MainActor [weak self] in self?.updateHeartRate(beatsPerMinute) }
    }

    nonisolated func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}
}
