//
//  CountdownRing.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct CountdownRing: View {
    public enum Size: CaseIterable, Sendable {
        case small
        case regular

        var diameter: CGFloat {
            switch self {
            case .small: 36
            case .regular: 44
            }
        }
    }

    let startedAt: Date
    let duration: TimeInterval
    let size: Size

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        startedAt: Date,
        duration: TimeInterval,
        size: Size = .regular
    ) {
        self.startedAt = startedAt
        self.duration = duration
        self.size = size
    }

    public var body: some View {
        TimelineView(schedule) { context in
            let state = Countdown(startedAt: startedAt, duration: duration).state(at: context.date, stepped: reduceMotion)
            CountdownRingFace(progress: state.progress, secondsLeft: state.secondsLeft, size: size)
                .transaction { $0.disablesAnimations = reduceMotion }
        }
    }

    private var schedule: CountdownSchedule {
        CountdownSchedule(startedAt: startedAt, stepped: reduceMotion)
    }
}

struct Countdown {
    struct State: Equatable {
        let progress: Double
        let secondsLeft: Int
    }

    let startedAt: Date
    let duration: TimeInterval

    func state(
        at date: Date,
        stepped: Bool
    ) -> State {
        let elapsed = min(max(date.timeIntervalSince(startedAt), 0), duration)
        let shown = stepped ? elapsed.rounded(.down) : elapsed
        return State(
            progress: duration > 0 ? shown / duration : 1,
            secondsLeft: Int((duration - elapsed).rounded(.up))
        )
    }
}

struct CountdownSchedule: TimelineSchedule {
    let startedAt: Date
    let stepped: Bool

    func entries(
        from startDate: Date,
        mode: TimelineScheduleMode
    ) -> AnyIterator<Date> {
        let interval: TimeInterval = stepped || mode == .lowFrequency ? 1 : 1.0 / 30
        let elapsed = max(startDate.timeIntervalSince(startedAt), 0)
        var next = startedAt.addingTimeInterval((elapsed / interval).rounded(.down) * interval)
        return AnyIterator {
            defer { next = next.addingTimeInterval(interval) }
            return next
        }
    }
}

struct CountdownRingFace: View {
    let progress: Double
    let secondsLeft: Int
    let size: CountdownRing.Size

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.chair.outline, lineWidth: Stroke.chair.bold)
            Circle()
                .trim(from: progress, to: 1)
                .stroke(Color.chair.ink, style: StrokeStyle(lineWidth: Stroke.chair.bold, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(secondsLeft)")
                .font(.system(size: size.diameter * 0.42, weight: .bold).monospacedDigit())
                .foregroundStyle(Color.chair.ink)
        }
        .frame(width: size.diameter, height: size.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Countdown")
        .accessibilityValue("\(secondsLeft) seconds")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview("Light") {
    CountdownRingPreview()
}

#Preview("Dark") {
    CountdownRingPreview()
        .preferredColorScheme(.dark)
}

#Preview("AX5") {
    CountdownRingPreview()
        .environment(\.dynamicTypeSize, .accessibility5)
}

struct CountdownRingPreview: View {
    var body: some View {
        HStack(spacing: Spacing.chair.md) {
            CountdownRingFace(progress: 0.4, secondsLeft: 3, size: .small)
            CountdownRingFace(progress: 0.7, secondsLeft: 3, size: .regular)
            CountdownRing(startedAt: .now, duration: 10)
        }
        .padding(Spacing.chair.md)
        .background(Color.chair.surface)
    }
}
