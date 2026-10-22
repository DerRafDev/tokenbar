import AppKit
import SwiftUI

/// Reports whether the hosting window is visible on screen.
///
/// `MenuBarExtra` keeps its window's view hierarchy alive between openings, so `onAppear`
/// is not a reliable "popover opened" signal. The window's occlusion state is.
struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: @MainActor (Bool) -> Void

    func makeNSView(context: Context) -> ObservingView {
        ObservingView(onChange: onChange)
    }

    func updateNSView(_ view: ObservingView, context: Context) {
        view.onChange = onChange
    }

    final class ObservingView: NSView {
        var onChange: @MainActor (Bool) -> Void
        private var observation: (any NSObjectProtocol)?
        private var lastReported: Bool?

        init(onChange: @escaping @MainActor (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observation { NotificationCenter.default.removeObserver(observation) }
            observation = nil
            guard let window else { return }

            observation = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.report() }
            }
            report()
        }

        private func report() {
            let visible = window?.occlusionState.contains(.visible) ?? false
            guard visible != lastReported else { return }
            lastReported = visible
            onChange(visible)
        }
    }
}
