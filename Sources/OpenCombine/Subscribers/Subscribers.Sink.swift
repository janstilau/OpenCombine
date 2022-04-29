//
//  Subscribers.Sink.swift
//  
//
//  Created by Sergej Jaskiewicz on 16.06.2019.
//

/*
 在 Combine 的体系里面, 节点对象
 
 上游节点, 生成一个 Subscription 对象, 存储在 Sink 里面, 而 Subscription 保持了下游的 Sink 对象. 这是一个强引用.
 Subscription 里面, 是上游节点如何接受上游节点, 操作, 然后输出给下游节点的逻辑.
 */
extension Subscribers {
    /// A simple subscriber that requests an unlimited number of values upon subscription
    // unlimited Demand. Demand 的设计, 不是说下游节点需要, 上游节点就要一直给. 而是上游节点不能超过需要的数量, 什么时候, 真正的触发信号的发送, 还是上游节点的责任.
    // 进行了类型的绑定. 写在泛型参数里面的类型, 不仅仅是一个抽象数据类型的概念, 也有类型绑定的含义在里面.
    
    /*
     我们想让 MySink 满足 Cancellable，因此需要持有 subscription，才能在未来取消这个订阅。在语义上来说，我们也不希望发生复制，所以使用 class 来声明 MySink。这也是实现自定义 Subscriber 的一般做法。
     喵神的博客. 可以看到, Cancellable 一般都是进行了上游节点的引用. 并且, 真正在相应链条中的, 一般都是引用类型.
     */
    public final class Sink<Input, Failure: Error>
    : Subscriber,
      Cancellable, // 因为, SINK 对象就是最后的节点对象了, 不会再次向后方传递. 所以, Sink 对象, 仅仅是 Cancellable 而不是 Subscription
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible {
        
        // 记录了, Next Event 应该触发的闭包.
        public var receiveValue: (Input) -> Void
        
        // 记录了, Complete Event 应该触发的闭包. 
        public var receiveCompletion: (Subscribers.Completion<Failure>) -> Void
        
        /*
         case awaitingSubscription
         case subscribed(Subscription)
         case pendingTerminal(Subscription)
         case terminal
         记录了, 当前自己的状态值. 同时, 在其中存储了 Subscription
         存储 Subscription, 可以进行 Demand 的动态管理. 不过, 在 Sink 中没有使用该技巧.
         还可以进行 Subscription 的 cancel 操作. 这是 Cancellable 应该做的事情, 在做完自己的资源释放之后, 要触发上游的 cancel
         */
        private var status = SubscriptionStatus.awaitingSubscription
        
        private let lock = UnfairLock.allocate()
        
        public var description: String { return "Sink" }
        
        public var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        public var playgroundDescription: Any { return description }
        
        // 因为, Sink 是最后节点, 所以没有 Subscribe 后方节点的操作, 他是一个 Subscriber, 而不是一个 Publisher
        public init(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
                    receiveValue: @escaping ((Input) -> Void)) {
            self.receiveCompletion = receiveCompletion
            self.receiveValue = receiveValue
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 要实现一个 Subscriber, 就要按照 Subscriber 的抽象来进行
        // 必须实现 receive(subscription: Subscription), 在里面调用 subscription.request 进行 Demand 的管理.
        // publisher.subscribe(subscriber) 完成的是, 响应链条的各个节点从后向前的串联.
        // receive(subscription: Subscription) 要完成的是, 响应链条的各个节点的循环引用的建立
        // func request(_ demand: Subscribers.Demand) 完成的是, 从后向前 Demand 的管理, 以及真正信号发出逻辑的触发.
        public func receive(subscription: Subscription) {
            lock.lock()
            // Guard 逻辑
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            // 存储了一下, 当前的 subscription, 形成了 Subscription 和 Subscriber 之间的循环引用.
            // 同时, 这里也管理了下状态. Swift 的 Enum 当做数据盒子, 使得业务数据和状态数据统一, 让逻辑更加清晰.
            // 在切换状态的时候, 自动进行内存的管理
            status = .subscribed(subscription)
            lock.unlock()
            
            // 然后, 触发 subscription 的 Demand 管理.
            // 如果使用 unlimited 进行管理, 那么就是 Rx 没有太大区别了. 也就是这个位置的 Subscriber 不做背压管理. 上游只要事件完成了, 就可以触发下游信号的接受.
            // 是否给下游节点, 发送信号, 是上游节点控制的. 如果上游节点不尊重下游节点的 RequestDemand 的意图, 就是上游节点的设计有问题.
            subscription.request(.unlimited)
        }
        
        // 当, 使用 unlimited 进行 Demand 管理之后, 每次 receive 的时候, 其实是不用进行 Demand 的考虑的.
        // 因为按照 Combine 的设计, Demand 是一个增量设计.
        public func receive(_ value: Input) -> Subscribers.Demand {
            // 在锁里面, 进行数据的读取.
            // 在锁外面, 进行操作的执行.
            // 这是一个, 非常通用的设计思路.
            lock.lock()
            let receiveValue = self.receiveValue
            lock.unlock()
            // Sink 里面, 接收到数据之后, 就是调用存储的闭包, 来处理这个数据.
            receiveValue(value)
            return .none
        }
        
        //  其实, 相当于这里调用了 cancel 了, 不知道为什么, Combine 里面, 在接收到结束事件的时候, 都没调用 cancel.
        public func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            // 这里, 对 Subscription 的强引用解除了. 同时, 进行了状态的管理.
            
            // 当, 一个节点认为自己该结束了, 一般
            status = .terminal
            let receiveCompletion = self.receiveCompletion
            self.receiveCompletion = { _ in }
            
            // We MUST release the closures AFTER unlocking the lock,
            // since releasing a closure may trigger execution of arbitrary code,
            // for example, if the closure captures an object with a deinit.
            // When closure deallocates, the object's deinit is called, and holding
            // the lock at that moment can lead to deadlocks.
            // See https://github.com/OpenCombine/OpenCombine/issues/208
            // 这里没太明白, 不重要.
            withExtendedLifetime(receiveValue) {
                receiveValue = { _ in }
                lock.unlock()
            }
            
            receiveCompletion(completion)
        }
        
        // Cancel 的责任是, 资源释放, 必要要做的是, 要完成对于上游节点的 cancel 触发.
        // 这样, 这个链条才能有意义.
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

// 添加 Operator, 或者 Subscriber, 有着固定的套路. 一定要在 Publisher Protocol 里面, 增加快捷方法, 进行链条构建的串联.
// 返回的时候, 应该使用 Any 进行类型的隐藏.
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
    /// This method creates the subscriber and immediately requests an unlimited number
    /// of values, prior to returning the subscriber.
    
    // 内存释放和 Cancel 的连动, 是 AnyCancellable 的行为. Sink 的 Deinit 里面, 没有做这件事.
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
        // 上游节点, 主动调用 subscribe, 完成整个响应链条的构建工作.
        subscribe(subscriber)
        // 主动进行类型的隐藏.
        // 实际上, subscribe 并不返回 cancel 对象. 如果返回了一个 cancel 对象, 是要在各个方法内专门进行声明的.
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
        // receiveCompletion 必然有值, 因为, Subscribers.Sink 里面这个成员变量并不是 Optional 的.
        // 坦率的说, 给很多成员变量, 添加一个默认的无效值, 可以大大简化类型的处理逻辑 .
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
