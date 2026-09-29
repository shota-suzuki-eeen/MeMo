import SwiftUI

extension View {
    /// Applies the native iOS 26 glass style while allowing call sites to keep
    /// their existing primary/secondary hierarchy and semantic tint.
    @ViewBuilder
    func memoGlassButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                buttonStyle(.glass)
                    .tint(tint)
            }
        } else {
            if prominent {
                buttonStyle(.borderedProminent)
                    .tint(tint)
            } else {
                buttonStyle(.bordered)
                    .tint(tint)
            }
        }
    }
}
