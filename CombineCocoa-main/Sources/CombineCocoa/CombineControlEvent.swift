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

/*
 对于 Publisher 来说, 实现有着固定的套路.
 func receive<S>(subscriber: S) where S : Subscriber, Self.Failure == S.Failure, Self.Output == S.Input
 对于 Publisher 来说,
 */

// 只是提供了 Publisher, 因为对于 Combine 来说, 天然就实现了 Assign on, 这种方式使得对于 UI 控件的赋值变得很简单.
// MARK: - Publisher
@available(iOS 13.0, *)
// 给系统的命名空间内添加控件, 这样的写法, 将自定义的修改, 纳入到了系统的控件之内.
public extension Combine.Publishers {
    /// A Control Event is a publisher that emits whenever the provided
    /// Control Events fire.
    struct ControlEvent<Control: UIControl>: Publisher {
        public typealias Output = Void
        public typealias Failure = Never // UI 事件, 永远不会失败.

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

        public func receive<S: Subscriber>(subscriber: S) where S.Failure == Failure, S.Input == Output {
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
    
    private final class Subscription<S: Subscriber, Control: UIControl>: Combine.Subscription where S.Input == Void {
        private var subscriber: S?
        weak private var control: Control? // 这里是弱引用,
        
        // 这个对象, 不会随着 Control 生命周期的消亡而消亡, 而是需要通过 downstream 释放对于它的引用才可以.
        // 在进行绑定完之后, 该将结果添加到 Anycancelable 就要添加进去.
        // 一般来说, 这个 Bag 集合和 UIControl 的生命周期是一致的, 都和 ContainerView 的生命周期一致. 
        deinit {
            Swift.print("ControlEvent Subscription \(self) Deinit")
        }

        init(subscriber: S, control: Control, event: Control.Event) {
            self.subscriber = subscriber
            self.control = control
            control.addTarget(self, action: #selector(processControlEvent), for: event)
        }

        func request(_ demand: Subscribers.Demand) {
            // We don't care about the demand at this point.
            // As far as we're concerned - UIControl events are endless until the control is deallocated.
        }

        func cancel() {
            subscriber = nil
        }

        @objc private func processControlEvent() {
            _ = subscriber?.receive()
        }
    }
}
#endif
