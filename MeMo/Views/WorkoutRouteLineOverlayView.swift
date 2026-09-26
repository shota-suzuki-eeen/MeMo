//
//  WorkoutRouteLineOverlayView.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/09.
//

import SwiftUI
import CoreLocation

enum WorkoutRouteOverlayPlacement: String, CaseIterable, Equatable {
    case center
    case bottomLeading

    mutating func toggle() {
        self = self == .center ? .bottomLeading : .center
    }

    var systemImage: String {
        "arrow.down.left.and.arrow.up.right"
    }

    var accessibilityLabel: String {
        switch self {
        case .center:
            return "ランルートを左下に移動"
        case .bottomLeading:
            return "ランルートを中央に移動"
        }
    }

    func frame(in size: CGSize) -> CGRect {
        switch self {
        case .center:
            let side = min(size.width * 0.68, 280)
            return CGRect(
                x: (size.width - side) * 0.5,
                y: (size.height - side) * 0.5,
                width: side,
                height: side
            )
        case .bottomLeading:
            let side = min(size.width * 0.34, 160)
            return CGRect(
                x: 24,
                y: size.height - side - 148,
                width: side,
                height: side
            )
        }
    }
}

struct WorkoutRouteLineOverlayView: View {
    let points: [WorkoutRoutePoint]
    let strokeColor: Color
    let placement: WorkoutRouteOverlayPlacement

    var body: some View {
        GeometryReader { geometry in
            let frame = placement.frame(in: geometry.size)

            WorkoutRouteLineCanvas(
                points: points,
                strokeColor: strokeColor
            )
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
        }
    }
}

private struct WorkoutRouteLineCanvas: View {
    let points: [WorkoutRoutePoint]
    let strokeColor: Color

    var body: some View {
        WorkoutRouteDrawingShape(points: points)
            .stroke(
                strokeColor,
                style: StrokeStyle(
                    lineWidth: 8,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

private struct WorkoutRouteDrawingShape: Shape {
    let points: [WorkoutRoutePoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let coordinates = points.map(\.coordinate)

        guard !coordinates.isEmpty else { return path }

        let xValues = coordinates.map(\.longitude)
        let yValues = coordinates.map(\.latitude)

        guard let minX = xValues.min(),
              let maxX = xValues.max(),
              let minY = yValues.min(),
              let maxY = yValues.max() else {
            return path
        }

        let width = max(maxX - minX, 0.00001)
        let height = max(maxY - minY, 0.00001)

        let insetRect = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
        let scale = min(insetRect.width / width, insetRect.height / height)
        let renderedWidth = width * scale
        let renderedHeight = height * scale

        let xOffset = insetRect.minX + (insetRect.width - renderedWidth) * 0.5
        let yOffset = insetRect.minY + (insetRect.height - renderedHeight) * 0.5

        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = xOffset + (coordinate.longitude - minX) * scale
            let y = yOffset + (maxY - coordinate.latitude) * scale
            return CGPoint(x: x, y: y)
        }

        if coordinates.count == 1, let coordinate = coordinates.first {
            let center = point(for: coordinate)
            let diameter = min(rect.width, rect.height) * 0.10
            path.addEllipse(
                in: CGRect(
                    x: center.x - (diameter * 0.5),
                    y: center.y - (diameter * 0.5),
                    width: diameter,
                    height: diameter
                )
            )
            return path
        }

        for (index, coordinate) in coordinates.enumerated() {
            let normalizedPoint = point(for: coordinate)
            if index == 0 {
                path.move(to: normalizedPoint)
            } else {
                path.addLine(to: normalizedPoint)
            }
        }

        return path
    }
}
