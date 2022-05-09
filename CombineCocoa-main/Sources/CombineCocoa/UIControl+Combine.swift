#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import UIKit

// 给 UIControl 添加一个扩展, 直接生成一个对应的 Publihser. 这是一个起始节点.
@available(iOS 13.0, *)
public extension UIControl {
    // A publisher emitting events from this control.
    // 这是一个工厂方法, 各个 UIControl 的子类, 根据自己的需要, 进行对应的 Publisher 的精细化处理.
    func controlEventPublisher(for events: UIControl.Event) -> AnyPublisher<Void, Never> {
        Publishers.ControlEvent(control: self, events: events).eraseToAnyPublisher()
    }
}

/*
 public extension UIButton {
 /// A publisher emitting tap events from this button.
 var tapPublisher: AnyPublisher<Void, Never> {
 controlEventPublisher(for: .touchUpInside)
 }
 }
 */
#endif
