//
//  StepModels.swift
//  MeMo
//
//  Created by shota suzuki on 2026/03/20.
//

import Foundation

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
