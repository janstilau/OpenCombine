//
//  CombineControlEvent.swift
//  CombineCocoa
//
//  Created by Shai Mishali on 01/08/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Combine
import Foundation
import UIKit.UIControl

// MARK: - Publisher

/*
 就如同, 各种惯例的 Publisher 的实现.
 Publisher 其实更多地是一个工厂类. 里面存储了该 Publisher 的应该持有的业务逻辑.
 如果是源头 Publisher, 则是在相应的时机, 要触发所存储的 Subscriber 的 Receive 方法, 将数据传递出去.
 如果是中间节点的 Publisher, 则是在接收到上游节点之后, 进行自己的业务加工, 然后将自己的加工结果, 交给后续处理.
 
 这里, 是一个源头的 Publisher, 所以, 它的主要责任就是, 在合适的时机, 进行后续数据的产生, 并且发射给后续节点.
 */

// 其实, 我觉得这里个泛型有点问题. 不需要泛型不更好吗. 直接使用父类对象进行编码了.
@available(iOS 13.0, *)
public extension Combine.Publishers {
    /// A Control Event is a publisher that emits whenever the provided
    /// Control Events fire.
    struct ControlEvent<Control: UIControl>: Publisher {
        public typealias Output = Void
        public typealias Failure = Never

        // 如同惯例实现, 对于 Publisher 来说, 生成的时候, 仅仅是进行数据的存储.
        // 真正节点的搭建, 是在 receive 的时候.
        private let control: Control
        private let controlEvents: Control.Event

        /// Initialize a publisher that emits a Void
        /// whenever any of the provided Control Events trigger.
        ///
        /// - parameter control: UI Control.
        /// - parameter events: Control Events.
        public init(control: Control,
                    events: Control.Event) {
            self.control = control
            self.controlEvents = events
        }

        // 真正的进行了链路的搭建.
        // subscriber 是下游先创建好传递过来的.
        // 在自己创建的 Inner 中, 将传递过来的 subscriber 当做 downstream 来处理.
        public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
            // 自家的 Subscription 类对象.
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
    // 必须规定好, 下游仅仅是接受事件, 没有数据要进行传递.
    private final class Subscription<S: Subscriber, Control: UIControl>: Combine.Subscription where S.Input == Void {
        
        // 存储下游.
        private var subscriber: S?
        // 存储 UIControl
        weak private var control: Control?

        init(subscriber: S, control: Control, event: Control.Event) {
            self.subscriber = subscriber
            self.control = control
            // 还是利用, target action 机制, 来完成 Publisher 的创建工作. 
            control.addTarget(self, action: #selector(handleEvent), for: event)
        }

        func request(_ demand: Subscribers.Demand) {
            // We don't care about the demand at this point.
            // As far as we're concerned - UIControl events are endless until the control is deallocated.
        }

        // 这样就打破了循环引用. 其实这个时候, 还应该进行 removeTarget 的操作.
        func cancel() {
            subscriber = nil
        }

        /*
         @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
         extension Subscriber where Self.Input == () {

             /// Tells the subscriber that a publisher of void elements is ready to receive further requests.
             ///
             /// Use `Void` inputs and outputs when you want to signal that an event has occurred, but don’t need to send the event itself.
             /// - Returns: A ``Subscribers/Demand`` instance indicating how many more elements the subscriber expects to receive.
             public func receive() -> Subscribers.Demand
         }
         */
        @objc private func handleEvent() {
            _ = subscriber?.receive()
        }
    }
}
#endif
