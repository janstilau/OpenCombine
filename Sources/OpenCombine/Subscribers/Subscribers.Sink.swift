//
//  Subscribers.Sink.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

/*
 和 Rx 不同, Sink 对象, 是一个 Cancellable 对象.
 
 上游节点, 生成一个 Subscription 对象, 存储在 Sink 里面, 而 Subscription 保持了下游的 Sink 对象. 这是一个强引用.
 Subscription 里面, 是上游节点如何接受上上游节点, 操作, 然后输出给下游节点的逻辑.
 Subscription 的 cancel, 就是打破这层逻辑的函数.
 
 Subscription 和 Sink 之间强引用, cancel 的时候, 强引用打破. 然后调用 Subscription 的 cancel.
 Subscription 的 cancel 打破强引用, 然后调用自己存储的上游 Subscription 的 cancel.
 如果是这样, 就和 Rx 是一个设计的思路. 
 */
extension Subscribers {
    
    /// A simple subscriber that requests an unlimited number of values upon subscription
    // 进行了类型的绑定.
    public final class Sink<Input, Failure: Error>
    : Subscriber,
      Cancellable,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    {
        
        // 记录了, Next Event 应该触发的闭包.
        public var receiveValue: (Input) -> Void
        
        // 记录了, Complete Event 应该触发的闭包. 
        public var receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        
        /*
         case awaitingSubscription
         case subscribed(Subscription)
         case pendingTerminal(Subscription)
         case terminal
         记录了, 当前自己的状态值.
         */
        private var status = SubscriptionStatus.awaitingSubscription
        
        private let lock = UnfairLock.allocate()
        
        public var description: String { return "Sink" }
        
        public var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        public var playgroundDescription: Any { return description }
        
        public init(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
                    receiveValue: @escaping ((Input) -> Void)) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 在实现一个 Subscriber 的实现, 一定要实现 func receive(subscription: Subscription) 这个方法.
        // 因为, 这才是真正触发响应联调操作的基础.
        // 在其中, 一定要触发 subscription.request
        public func receive(subscription: Subscription) {
            lock.lock()
            // 自己的状态, 必须是 init 的状态. 
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 存储了一下, 当前的 subscription
            // 这里, 会形成强引用.
            status = .subscribed(subscription)
            lock.unlock()
            // 然后, 触发 subscription 的 Demand 管理.
            subscription.request(.unlimited)
        }
        
        // Sink 在 receive(subscription: Subscription) 中, 将自己期望的 demand 设置为 max. 所以, 在每次的 receive 的时候, 返回 0, 也不用担心上游次数用尽了. 
        public func receive(_ value: Input) -> Subscribers.Demand {
            // 在锁里面, 进行数据的读取.
            // 在锁外面, 进行操作的执行.
            // 这是一个, 非常通用的设计思路.
            lock.lock()
            let receiveValue = self.receiveValue
            lock.unlock()
            receiveValue(value)
            return .none
        }
        
        //  其实, 相当于这里调用了 cancel 了, 不知道为什么, Combine 里面, 在接收到结束事件的时候, 都没调用 cancel.
        public func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            // 这里, 对 Subscription 的强引用解除了.
            status = .terminal
            let receiveCompletion = self.receiveCompletion
            self.receiveCompletion = { _ in }
            
            // We MUST release the closures AFTER unlocking the lock,
            // since releasing a closure may trigger execution of arbitrary code,
            // for example, if the closure captures an object with a deinit.
            // When closure deallocates, the object's deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            // See https://github.com/OpenCombine/OpenCombine/issues/208
            
            withExtendedLifetime(receiveValue) {
                receiveValue = { _ in }
                lock.unlock()
            }
            
            receiveCompletion(completion)
        }
        
        public func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            
            // We MUST release the closures AFTER unlocking the lock,
            // since releasing a closure may trigger execution of arbitrary code,
            // for example, if the closure captures an object with a deinit.
            // When closure deallocates, the object's deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            // See https://github.com/OpenCombine/OpenCombine/issues/208
            
            // Evaluates a closure while ensuring that the given instance is not destroyed before the closure returns.
            withExtendedLifetime((receiveValue, receiveCompletion)) {
                receiveCompletion = { _ in }
                receiveValue = { _ in }
                lock.unlock()
            }
            // 最终, 是要执行, subscription.cancel 方法的.
            subscription.cancel()
        }
    }
}

// 最重要的方法, 将响应式转化为命令式.
// 这是, 不习惯 Combine 的时候, 使用的最广的转化函数.
extension Publisher {
    
    /// Attaches a subscriber with closure-based behavior.
    ///
    /// Use `sink(receiveCompletion:receiveValue:)` to observe values received by
    /// the publisher and process them using a closure you specify.
    ///
    /// In this example, a `Range` publisher publishes integers to
    /// a `sink(receiveCompletion:receiveValue:)` operator’s `receiveValue` closure that
    /// prints them to the console. Upon completion
    /// the `sink(receiveCompletion:receiveValue:)` operator’s `receiveCompletion` closure
    /// indicates the successful termination of the stream.
    ///
    ///     let myRange = (0...3)
    ///     cancellable = myRange.publisher
    ///         .sink(receiveCompletion: { print ("completion: \($0)") },
    ///               receiveValue: { print ("value: \($0)") })
    ///
    ///     // Prints:
    ///     //  value: 0
    ///     //  value: 1
    ///     //  value: 2
    ///     //  value: 3
    ///     //  completion: finished
    ///
    // requests an unlimited number, 使用这种方式, Demian 是 Max.
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    /// The return value should be held, otherwise the stream will be canceled.
    ///
    /// - parameter receiveComplete: The closure to execute on completion.
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of
    ///   the received value. Deallocation of the result will tear down the subscription
    ///   stream.
    public func sink(
        receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
        receiveValue: @escaping ((Output) -> Void)
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: receiveCompletion,
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

extension Publisher where Failure == Never {
    
    /// Attaches a subscriber with closure-based behavior to a publisher that never fails.
    ///
    /// Use `sink(receiveValue:)` to observe values received by the publisher and print
    /// them to the console. This operator can only be used when the stream doesn’t fail,
    /// that is, when the publisher’s `Failure` type is `Never`.
    ///
    /// In this example, a `Range` publisher publishes integers to a `sink(receiveValue:)`
    /// operator’s `receiveValue` closure that prints them to the console:
    ///
    ///     let integers = (0...3)
    ///     integers.publisher
    ///         .sink { print("Received \($0)") }
    ///
    ///     // Prints:
    ///     //  Received 0
    ///     //  Received 1
    ///     //  Received 2
    ///     //  Received 3
    ///
    /// This method creates the subscriber and immediately requests an unlimited number of
    /// values, prior to returning the subscriber.
    /// The return value should be held, otherwise the stream will be canceled.
    ///
    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of
    ///   the received value. Deallocation of the result will tear down the subscription
    ///   stream.
    public func sink(
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
