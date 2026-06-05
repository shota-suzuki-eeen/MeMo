//
//  MeMoWidgetBundle.swift
//  MeMoWidgetExtension
//
//  Widget Extension entry point.
//  Keep @main in this file only for the MeMoWidgetExtension target.
//

import SwiftUI
import WidgetKit

@main
struct MeMoWidgetBundle: WidgetBundle {
    var body: some Widget {
        MeMoWidget()
        MeMoWidgetLiveActivity()
    }
}
