import SwiftUI

extension View {
    @ViewBuilder
    func horizontalDragGesture(
        onChanged: ((CGSize) -> Void)? = nil,
        onEnded: ((CGSize) -> Void)? = nil
    ) -> some View {
        if #available(iOS 18.0, *) {
            gesture(
                HorizontalPanGesture()
                    .onChanged { onChanged?($0) }
                    .onEnded { onEnded?($0) }
            )
        } else {
            gesture(
                DragGesture()
                    .onChanged { onChanged?($0.translation) }
                    .onEnded { onEnded?($0.translation) }
            )
        }
    }
}

@available(iOS 18.0, *)
private struct HorizontalPanGesture: UIGestureRecognizerRepresentable {
    var onChanged: ((CGSize) -> Void)?
    var onEnded: ((CGSize) -> Void)?

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        gesture.maximumNumberOfTouches = 1
        gesture.cancelsTouchesInView = false
        gesture.delegate = context.coordinator
        return gesture
    }

    func updateUIGestureRecognizer(
        _ recognizer: UIPanGestureRecognizer,
        context: Context
    ) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func onChanged(_ action: @escaping (CGSize) -> Void) -> Self {
        var copy = self
        copy.onChanged = action
        return copy
    }

    func onEnded(_ action: @escaping (CGSize) -> Void) -> Self {
        var copy = self
        copy.onEnded = action
        return copy
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: ((CGSize) -> Void)?
        var onEnded: ((CGSize) -> Void)?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return false
            }
            let velocity = panGesture.velocity(in: gestureRecognizer.view)
            return abs(velocity.x) > abs(velocity.y)
        }

        @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            let size = CGSize(width: translation.x, height: translation.y)
            switch gestureRecognizer.state {
            case .changed:
                onChanged?(size)
            case .ended, .cancelled, .failed:
                onEnded?(size)
            default:
                break
            }
        }
    }
}
