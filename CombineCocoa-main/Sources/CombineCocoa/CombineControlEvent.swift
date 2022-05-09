// 这应该是抄的 Rx 的逻辑.

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import Foundation
import UIKit.UIControl

/*
 Target Action 模式下形成的 Publisher, 是比较容易理解的.
 这个库里面, 最最麻烦的是 Delegate 的相关方法. 是用的 ForwardInvocation 这种技术实现的.
 不如 Rx 的复杂, 但是使用的是同样的思想. 
 */

// 给 Publishers 这个作用域, 增加一个扩展类型.
// MARK: - Publisher
@available(iOS 13.0, *)
public extension Combine.Publishers {
    // 惯例, Publisher 就是收集信息的场合.
    // 但是, 还是要真正的一个对象, 来触发信号的发送. 这个对象, 在这里, 就是 ControlEvent.Subscription
    
    /// A Control Event is a publisher that emits whenever the provided
    /// Control Events fire.
    struct ControlEvent<Control: UIControl>: Publisher {
        public typealias Output = Void
        public typealias Failure = Never
        
        // Publisher 里面, 强引用没有什么关系. 因为这只是一个生成器, 一般不会进行存储的.
        private let control: Control
        private let controlEvents: Control.Event
        
        /// Initialize a publisher that emits a Void
        /// whenever any of the provided Control Events trigger.
        // Publisher 的惯例做法, 收集信息, 然后创建对应的 Subscription 节点.
        public init(control: Control,
                    events: Control.Event) {
            self.control = control
            self.controlEvents = events
        }
        
        public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
            // 在 Combine 中, 真正的节点, 是各个 Publisher 对应的 Subscription
            let subscription = Subscription(subscriber: subscriber,
                                            control: control,
                                            event: controlEvents)
            subscriber.receive(subscription: subscription)
        }
    }
}

// MARK: - Subscription
@available(iOS 13.0, *)
extension Combine.Publishers.ControlEvent {
    // 这个只会是 Subscription 的类型, 不会是 Subscriber. 因为, 这个 Publisher 生成的, 只会是起始节点, 不会是 Opertor 节点.
    private final class Subscription<S: Subscriber, Control: UIControl>: Combine.Subscription where S.Input == Void {
        // 存储, downstream 节点.
        private var subscriber: S?
        // 使用 Weak, 来进行了相关的索引.
        weak private var control: Control?
        
        init(subscriber: S, control: Control, event: Control.Event) {
            self.subscriber = subscriber
            self.control = control
            control.addTarget(self, action: #selector(handleEvent), for: event)
        }
        
        
        func request(_ demand: Subscribers.Demand) {
            // We don't care about the demand at this point.
            // As far as we're concerned - UIControl events are endless until the control is deallocated.
        }
        
        // 这里, 其实还应该增加 Control 的 Remove Target 相关的操作.
        func cancel() {
            subscriber = nil
        }
        
        // 处理的唯一的办法, 就是给后面节点发送一个信号.
        @objc private func handleEvent() {
            _ = subscriber?.receive()
        }
    }
}
#endif
