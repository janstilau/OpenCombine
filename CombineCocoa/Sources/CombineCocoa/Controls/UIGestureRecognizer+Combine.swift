
#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit


// 所有的都是, 将对应的 Subscription, 作为 Gesture 的 Target, 这样就可以在自己被触发的时候, 发送事件到后方了.
// MARK: - Gesture Publishers
@available(iOS 13.0, *)
public extension UITapGestureRecognizer {
    /// A publisher which emits when this Tap Gesture Recognizer is triggered
    var tapPublisher: AnyPublisher<UITapGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UIPinchGestureRecognizer {
    /// A publisher which emits when this Pinch Gesture Recognizer is triggered
    var pinchPublisher: AnyPublisher<UIPinchGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UIRotationGestureRecognizer {
    /// A publisher which emits when this Rotation Gesture Recognizer is triggered
    var rotationPublisher: AnyPublisher<UIRotationGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UISwipeGestureRecognizer {
    /// A publisher which emits when this Swipe Gesture Recognizer is triggered
    var swipePublisher: AnyPublisher<UISwipeGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UIPanGestureRecognizer {
    /// A publisher which emits when this Pan Gesture Recognizer is triggered
    var panPublisher: AnyPublisher<UIPanGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UIScreenEdgePanGestureRecognizer {
    /// A publisher which emits when this Screen Edge Gesture Recognizer is triggered
    var screenEdgePanPublisher: AnyPublisher<UIScreenEdgePanGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

@available(iOS 13.0, *)
public extension UILongPressGestureRecognizer {
    /// A publisher which emits when this Long Press Recognizer is triggered
    var longPressPublisher: AnyPublisher<UILongPressGestureRecognizer, Never> {
        gesturePublisher(for: self)
    }
}

// MARK: - Private Helpers

// A private generic helper function which returns the provided
// generic publisher whenever its specific event occurs.
@available(iOS 13.0, *)
private func gesturePublisher<Gesture: UIGestureRecognizer>(for gesture: Gesture) -> AnyPublisher<Gesture, Never> {
    Publishers.ControlTarget(control: gesture,
                             addTargetAction: { gesture, target, action in
                                gesture.addTarget(target, action: action)
                             },
                             removeTargetAction: { gesture, target, action in
                                gesture?.removeTarget(target, action: action)
                             })
              .subscribe(on: DispatchQueue.main)
              .map { gesture }
              .eraseToAnyPublisher()
}
#endif
