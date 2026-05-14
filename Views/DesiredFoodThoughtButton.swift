//
//  DesiredFoodThoughtButton.swift
//  MeMo
//
//  Displays the current desired food on top of food_button.
//

import SwiftUI

struct DesiredFoodThoughtButton: View {
    let desiredFood: FoodCatalog.FoodItem?
    let size: CGFloat
    let amplitude: CGFloat
    let duration: Double
    let action: () -> Void

    @State private var startDate: Date = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let cycle = max(duration, 0.01)
            let phase = (elapsed / cycle) * (.pi * 2)
            let yOffset = CGFloat(sin(phase)) * amplitude

            Button(action: action) {
                ZStack {
                    Color.clear
                        .frame(width: size, height: size)

                    Image("food_button")
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)

                    if let desiredFood {
                        Image(desiredFood.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size * 0.48, height: size * 0.48)
                            .offset(y: -size * 0.15)
                            .transition(.scale(scale: 0.86).combined(with: .opacity))
                            .id(desiredFood.id)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: size, height: size)
                .contentShape(Rectangle())
                .offset(y: yOffset)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            startDate = Date()
        }
        .onChange(of: desiredFood?.id) { _, _ in
            startDate = Date()
        }
    }
}
