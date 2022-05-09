
#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import Foundation
import UIKit.UIControl

// MARK: - Publisher


@available(iOS 13.0, *)
public extension Combine.Publishers {
    // 和 Rx 的不同, ControlProperty 的仅仅有 Publisher 的能力.
    // 难道是因为 assign on 已经不需要 Setter 了??
    
    // 当, 对应的 Event 触发之后, 使用 KeyPath 获取对应的值, 然后将值传递给后续的节点.
    /// A Control Property is a publisher that emits the value at the provided keypath
    /// whenever the specific control events are triggered. It also emits the keypath's
    /// initial value upon subscription.
    
    // 惯例实现, Publisher 仅仅是数据的收集者.
    struct ControlProperty<Control: UIControl, Value>: Publisher {
        public typealias Output = Value
        public typealias Failure = Never

        // 根据, Keypath 来确定 Output 的值的类型.
        private let control: Control
        private let controlEvents: Control.Event
        private let keyPath: KeyPath<Control, Value>

        /// Initialize a publisher that emits the value at the specified keypath
        /// whenever any of the provided Control Events trigger.
        public init(control: Control,
                    events: Control.Event,
                    keyPath: KeyPath<Control, Value>) {
            self.control = control
            self.controlEvents = events
            self.keyPath = keyPath
        }

        // Publihser 能够创建节点, 来面对后续节点的 Attach 请求.
        public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
            let subscription = Subscription(subscriber: subscriber,
                                            control: control,
                                            event: controlEvents,
                                            keyPath: keyPath)
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: - Subscription
@available(iOS 13.0, *)
extension Combine.Publishers.ControlProperty {
    // 这是一个起始节点, 所以不必来作为 Subscriber
    private final class Subscription<S: Subscriber, Control: UIControl, Value>: Combine.Subscription where S.Input == Value {
        private var subscriber: S?
        weak private var control: Control?
        let keyPath: KeyPath<Control, Value>
        private var didEmitInitial = false
        private let event: Control.Event

        init(subscriber: S, control: Control, event: Control.Event, keyPath: KeyPath<Control, Value>) {
            self.subscriber = subscriber
            
            self.keyPath = keyPath
            self.control = control
            self.event = event
            control.addTarget(self, action: #selector(handleEvent), for: event)
        }
        
        // Publihser 的责任, 就是它所创造的节点, 能够主动地发送信号, 给它的后续节点.
        // 这里就是 Porperty 可以作为 Publisher 的原因. 主动地处理了 TargetAction, 每次触发, 都把当前的最新值, 传递出去.
        @objc private func handleEvent() {
            guard let control = control else { return }
            _ = subscriber?.receive(control[keyPath: keyPath])
        }

        func request(_ demand: Subscribers.Demand) {
            // Emit initial value upon first demand request
            // 在第一次, Subscriber 需要数据的时候, 把当前的数据传递过去.
            if !didEmitInitial,
                demand > .none,
                let control = control,
                let subscriber = subscriber {
                _ = subscriber.receive(control[keyPath: keyPath])
                didEmitInitial = true
            }

            // We don't care about the demand at this point.
            // As far as we're concerned - UIControl events are endless until the control is deallocated.
        }

        func cancel() {
            control?.removeTarget(self, action: #selector(handleEvent), for: event)
            subscriber = nil
        }
    }
}

extension UIControl.Event {
    static var defaultValueEvents: UIControl.Event {
        return [.allEditingEvents, .valueChanged]
    }
}
#endif
