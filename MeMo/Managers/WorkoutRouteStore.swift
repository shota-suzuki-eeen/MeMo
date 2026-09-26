//
//  WorkoutRouteStore.swift
//  MeMo
//
//  Created by shota suzuki on 2026/04/07.
//

import Foundation
import SwiftData

struct WorkoutRouteStore {
    func save(
        draft: WorkoutSessionDraft,
        in context: ModelContext
    ) throws -> WorkoutSessionRecord {
        let routeData = try WorkoutSessionRecord.encodeRoutePoints(draft.routePoints)
        let record = WorkoutSessionRecord(draft: draft, routeData: routeData)
        context.insert(record)
        try context.save()
        return record
    }
}
