//
//  StepModels.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation
import SwiftData
import CoreLocation

struct StepLog: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let delta: Int
    let totalAfter: Int
    let dayTotal: Int
    let weekTotal: Int
    let rewardsGranted: Int
    let satDelta: Int

    init(
        id: UUID = UUID(),
        date: Date,
        delta: Int,
        totalAfter: Int,
        dayTotal: Int,
        weekTotal: Int,
        rewardsGranted: Int,
        satDelta: Int
    ) {
        self.id = id
        self.date = date
        self.delta = delta
        self.totalAfter = totalAfter
        self.dayTotal = dayTotal
        self.weekTotal = weekTotal
        self.rewardsGranted = rewardsGranted
        self.satDelta = satDelta
    }
}

struct WorkoutRoutePoint: Codable, Identifiable, Equatable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let horizontalAccuracy: Double

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        timestamp: Date,
        horizontalAccuracy: Double
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
    }

    init(location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp,
            horizontalAccuracy: location.horizontalAccuracy
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WorkoutSessionDraft: Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let elapsedSeconds: Int
    let totalDistanceMeters: Double
    let routePoints: [WorkoutRoutePoint]
    let memo: String?
    let characterID: String?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        elapsedSeconds: Int,
        totalDistanceMeters: Double,
        routePoints: [WorkoutRoutePoint],
        memo: String? = nil,
        characterID: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.totalDistanceMeters = max(0, totalDistanceMeters)
        self.routePoints = routePoints
        self.memo = memo?.nilIfBlank
        self.characterID = characterID?.nilIfBlank
    }

    var distanceKilometers: Double {
        totalDistanceMeters / 1000.0
    }
}

@Model
final class WorkoutSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var elapsedSeconds: Int
    var totalDistanceMeters: Double
    var routeData: Data
    var memo: String?
    var characterID: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        elapsedSeconds: Int,
        totalDistanceMeters: Double,
        routeData: Data,
        memo: String? = nil,
        characterID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.totalDistanceMeters = max(0, totalDistanceMeters)
        self.routeData = routeData
        self.memo = memo?.nilIfBlank
        self.characterID = characterID?.nilIfBlank
        self.createdAt = createdAt
    }

    convenience init(draft: WorkoutSessionDraft, routeData: Data) {
        self.init(
            id: draft.id,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            elapsedSeconds: draft.elapsedSeconds,
            totalDistanceMeters: draft.totalDistanceMeters,
            routeData: routeData,
            memo: draft.memo,
            characterID: draft.characterID
        )
    }

    var routePoints: [WorkoutRoutePoint] {
        (try? JSONDecoder().decode([WorkoutRoutePoint].self, from: routeData)) ?? []
    }

    var distanceKilometers: Double {
        totalDistanceMeters / 1000.0
    }
}

extension WorkoutSessionRecord {
    static func encodeRoutePoints(_ points: [WorkoutRoutePoint]) throws -> Data {
        try JSONEncoder().encode(points)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
