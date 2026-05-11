//
//  MemoIPadPresentedPhoneCanvas.swift
//  MeMo
//
//  iOS 18.6+
//
//  iPad only:
//  Keeps SwiftUI fullScreenCover contents at the same fixed phone-sized canvas
//  used by HomeView, without changing iPhone behavior.
//
//  Important:
//  This file intentionally does NOT resize UIKit / UIHostingController frames.
//  Resizing the UIKit presentation frame can make SwiftUI child views keep the
//  original iPad-wide layout and then get clipped, which caused the StepView
//  activity screen to be cut off horizontally.
//

import SwiftUI
import UIKit

enum MemoIPadPresentedPhoneCanvas {
    @MainActor
    static func installIfNeeded() {
        // No-op by design.
        // The active implementation is the SwiftUI modifier below.
        // Keeping this method prevents build errors if MeMoApp.swift still calls it.
    }
}

// MARK: - Presented Phone Canvas

private struct MemoIPadPresentedPhoneCanvasModifier: ViewModifier {
    private enum Layout {
        // Keep this value in sync with MemoIPadPhoneCanvasModifier in MeMoApp.swift.
        static let phoneSize = CGSize(width: 393, height: 852)
        static let cornerRadius: CGFloat = 42
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if MemoDevice.isIPad {
            GeometryReader { proxy in
                ZStack {
                    Color.clear
                        .ignoresSafeArea()

                    content
                        .frame(width: Layout.phoneSize.width, height: Layout.phoneSize.height)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: Layout.cornerRadius,
                                style: .continuous
                            )
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: Layout.cornerRadius,
                                style: .continuous
                            )
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 14)
                        .position(
                            x: proxy.size.width * 0.5,
                            y: proxy.size.height * 0.5
                        )
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(
                    MemoPresentedTransparentBackgroundApplier()
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                )
            }
            .ignoresSafeArea()
            .ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            content
        }
    }
}

extension View {
    func memoIPadPresentedPhoneCanvas() -> some View {
        modifier(MemoIPadPresentedPhoneCanvasModifier())
    }
}

// MARK: - Transparent Presented Background

private struct MemoPresentedTransparentBackgroundApplier: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        DispatchQueue.main.async {
            makePresentationTransparent(from: view)
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            makePresentationTransparent(from: uiView)
        }
    }

    private func makePresentationTransparent(from view: UIView) {
        guard MemoDevice.isIPad else { return }

        var current: UIView? = view
        var depth = 0

        while let targetView = current, depth < 10 {
            targetView.backgroundColor = .clear
            current = targetView.superview
            depth += 1
        }

        view.window?.backgroundColor = .clear
        view.window?.rootViewController?.view.backgroundColor = .clear
        makeViewControllerTreeTransparent(view.window?.rootViewController)
    }

    private func makeViewControllerTreeTransparent(_ viewController: UIViewController?) {
        guard let viewController else { return }

        viewController.view.backgroundColor = .clear

        for child in viewController.children {
            makeViewControllerTreeTransparent(child)
        }

        makeViewControllerTreeTransparent(viewController.presentedViewController)
    }
}
