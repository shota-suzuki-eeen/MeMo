//
//  MemoTutorialGachaView.swift
//  MeMo
//
//  Mandatory onboarding gacha bridge.
//  The tutorial opens the real GachaView directly from the onboarding spotlight.
//  iOS 18.6+
//

import SwiftUI

struct MemoTutorialGachaView: View {
    let state: AppState
    let onFinish: () -> Void

    var body: some View {
        GachaView(
            isTutorialMode: true,
            onTutorialFinished: onFinish
        )
    }
}

#if DEBUG
#Preview("Tutorial Gacha Placeholder") {
    Text("Preview requires AppState from the app runtime")
        .padding()
}
#endif
