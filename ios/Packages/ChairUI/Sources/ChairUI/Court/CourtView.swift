//
//  CourtView.swift
//  ChairUI
//
//  Created by Aaron Musa on 10/27/26.
//

import SwiftUI

public struct CourtView: View {
    let orientation: CourtOrientation
    let players: [PlayerMarker]
    let targetZones: [CourtZone]
    let ballMark: BallMark?

    public init(
        orientation: CourtOrientation = .portrait,
        players: [PlayerMarker] = [],
        targetZones: [CourtZone] = [],
        ballMark: BallMark? = nil
    ) {
        self.orientation = orientation
        self.players = players
        self.targetZones = targetZones
        self.ballMark = ballMark
    }

    public var body: some View {
        GeometryReader { proxy in
            let coordinate = CourtCoordinate(size: proxy.size, orientation: orientation)
            ZStack(alignment: .topLeading) {
                CourtLines(coordinate: coordinate)
                    .stroke(Color.chair.court, lineWidth: Stroke.chair.regular)
                ForEach(targetZones) { zone in
                    zoneShape(zone, in: coordinate)
                }
                if let ballMark {
                    ballMarkView(ballMark, in: coordinate)
                }
                ForEach(players) { player in
                    markerView(player, in: coordinate)
                }
            }
        }
        .aspectRatio(CourtCoordinate.aspectRatio(for: orientation), contentMode: .fit)
        .background(Color.chair.surface)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Court")
        .accessibilityValue(accessibilitySummary)
    }

    private func zoneShape(
        _ zone: CourtZone,
        in coordinate: CourtCoordinate
    ) -> some View {
        let rect = coordinate.rect(zone.from, zone.to)
        return Rectangle()
            .stroke(Color.chair.ink, style: StrokeStyle(lineWidth: Stroke.chair.thin, dash: [4, 3]))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    @ViewBuilder
    private func ballMarkView(
        _ mark: BallMark,
        in coordinate: CourtCoordinate
    ) -> some View {
        let centre = coordinate.point(mark.point)
        let diameter = markDiameter(coordinate) * 0.6
        Group {
            switch mark.call {
            case .in:
                Circle().fill(Color.chair.ink)
            case .out:
                Image(systemName: "xmark")
                    .resizable()
                    .fontWeight(.bold)
                    .foregroundStyle(Color.chair.danger)
            }
        }
        .frame(width: diameter, height: diameter)
        .position(centre)
    }

    private func markerView(
        _ player: PlayerMarker,
        in coordinate: CourtCoordinate
    ) -> some View {
        let colour = player.side == .near ? Color.chair.playerA : Color.chair.playerB
        let diameter = markDiameter(coordinate) * (player.role == .partner ? 0.8 : 1)
        return ZStack {
            Circle().fill(Color.chair.surface)
            if player.role == .receiver {
                Circle().strokeBorder(colour, lineWidth: Stroke.chair.bold)
            } else {
                Circle().fill(colour)
            }
        }
        .frame(width: diameter, height: diameter)
        .position(coordinate.point(player.position))
    }

    private func markDiameter(_ coordinate: CourtCoordinate) -> CGFloat {
        min(max(coordinate.pointsPerMetre * 1.1, 8), 16)
    }

    private var accessibilitySummary: String {
        let roles = players.map { player -> String in
            let side = player.side == .near ? "near" : "far"
            return "\(player.id), \(side) side, \(player.role)"
        }
        return roles.joined(separator: "; ")
    }
}

struct CourtLines: Shape {
    let coordinate: CourtCoordinate

    func path(in _: CGRect) -> Path {
        let half = CourtDimensions.halfLength
        let doubles = CourtDimensions.halfDoublesWidth
        let singles = CourtDimensions.halfSinglesWidth
        let service = CourtDimensions.serviceLineFromNet
        let mark = CourtDimensions.centreMarkLength

        var path = Path()
        func line(
            _ from: CourtPoint,
            _ to: CourtPoint
        ) {
            path.move(to: coordinate.point(from))
            path.addLine(to: coordinate.point(to))
        }

        path.addRect(coordinate.rect(CourtPoint(x: -doubles, y: -half), CourtPoint(x: doubles, y: half)))
        line(CourtPoint(x: -singles, y: -half), CourtPoint(x: -singles, y: half))
        line(CourtPoint(x: singles, y: -half), CourtPoint(x: singles, y: half))
        line(CourtPoint(x: -doubles, y: 0), CourtPoint(x: doubles, y: 0))
        line(CourtPoint(x: -singles, y: -service), CourtPoint(x: singles, y: -service))
        line(CourtPoint(x: -singles, y: service), CourtPoint(x: singles, y: service))
        line(CourtPoint(x: 0, y: -service), CourtPoint(x: 0, y: service))
        line(CourtPoint(x: 0, y: -half), CourtPoint(x: 0, y: -half + mark))
        line(CourtPoint(x: 0, y: half), CourtPoint(x: 0, y: half - mark))
        return path
    }
}

#Preview("Portrait") {
    CourtViewPreview(orientation: .portrait)
        .frame(width: 340)
}

#Preview("Mini") {
    CourtViewPreview(orientation: .portrait)
        .frame(width: 110)
}

#Preview("Landscape dark") {
    CourtViewPreview(orientation: .landscape)
        .frame(width: 600)
        .preferredColorScheme(.dark)
}

struct CourtViewPreview: View {
    let orientation: CourtOrientation

    var body: some View {
        CourtView(
            orientation: orientation,
            players: [
                PlayerMarker(id: "Musa", side: .near, position: .behindBaseline(.near, on: .deuce, by: 1), role: .server),
                PlayerMarker(id: "Reyes", side: .far, position: .behindBaseline(.far, on: .deuce, by: 0.5, fromCentre: 3), role: .receiver),
            ],
            targetZones: [
                CourtZone(
                    id: "deuce box",
                    from: CourtPoint(x: -CourtDimensions.halfSinglesWidth, y: 0),
                    to: CourtPoint(x: 0, y: CourtDimensions.serviceLineFromNet)
                ),
            ],
            ballMark: BallMark(CourtPoint(x: -2, y: 4.5), call: .in)
        )
    }
}
