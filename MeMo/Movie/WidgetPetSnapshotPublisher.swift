//
//  WidgetPetSnapshotPublisher.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

struct WidgetPetSnapshotPublisher {
    static func makeSnapshot(state: AppState, todaySteps: Int, now: Date = Date()) -> WidgetPetSnapshot {
        WidgetPetSnapshot(
            toiletFlag: state.toiletFlagAt != nil,
            bathFlag: state.hasBathFlag,
            currentPetID: state.currentPetID,
            todaySteps: max(0, todaySteps)
        )
    }
}
