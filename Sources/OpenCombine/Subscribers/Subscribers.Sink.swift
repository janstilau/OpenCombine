// Failure  == Never ???
extension Publisher where Failure == Never {
    /// Attaches a subscriber with closure-based behavior to a publisher that never fails.
    
    /// Use `sink(receiveValue:)` to observe values received by the publisher and print
    /// them to the console.  
    /// This operator can only be used when the stream doesn’t fail,
    /// that is, when the publisher’s `Failure` type is `Never`.
    
    /// In this example, a `Range` publisher publishes integers to a `sink(receiveValue:)`
    /// operator’s `receiveValue` closure that prints them to the console:
    
    ///
    ///     let integers = (0...3)
    ///     integers.publisher
    ///         .sink { print("Received \($0)") }
    
    ///     // Prints:
    ///     //  Received 0
    ///     //  Received 1
    ///     //  Received 2
    ///     //  Received 3
    
    /// This method creates the subscriber and immediately requests an unlimited number of
    /// values, prior to returning the subscriber.
    /// The return value should be held, otherwise the stream will be canceled.

    /// - parameter receiveValue: The closure to execute on receipt of a value.
    /// - Returns: A cancellable instance, which you use when you end assignment of
    ///   the received value. Deallocation of the result will tear down the subscription
    ///   stream.
    
    // 只有, Failure 类型是 Never 的时候, 才能使用这个 Operator.
    public func sink(
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        // receiveCompletion 必然有值, 因为, Subscribers.Sink 里面这个成员变量并不是 Optional 的.
        // 坦率的说, 给很多成员变量, 添加一个默认的无效值, 可以大大简化类型的处理逻辑 .
        
        // Never 其实是一个特殊的类型, 可以认为是泛型特化.
        // 当, Error 是 Never 的时候, 该类型就可以调用这个特殊版本的方法了.
        let subscriber = Subscribers.Sink<Output, Failure>(
            receiveCompletion: { _ in },
            receiveValue: receiveValue
        )
        subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}

// 添加 Operator, 或者 Subscriber, 有着固定的套路. 一定要在 Publisher Protocol 里面, 增加快捷方法, 进行链条构建的串联.
// 返回的时候, 应该使用 Any 进行类型的隐藏.
extension Publisher {
    
    // Attach, 一定要多使用这个词, 这是 Combine 里面, 非常重要的一个词.
    /// Attaches a subscriber with closure-based behavior.
    
    /// Use `sink(receiveCompletion:receiveValue:)` to observe values received by
    /// the publisher and process them using a closure you specify.
    
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
    // Subscription 相比较于 Cancellable, 多了一个后续节点 requestDemand 的需求.
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
        // 这个一个通用的设计, 各个 Operator 的 Subscription, 基本内部都有着这样的一个值.
        // 这可以认为是, enum 当做存储类型来使用的一个例子. 既可以当做标识类型, 也可以当做存储类型. 并且, 具有内存管理的作用.
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
            status = .subscribed(subscription)
            lock.unlock()
            
            // 必须触发上游的背压管理.
            // 这是 Combine 的设计思路.
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
            status = .terminal
            let receiveCompletion = self.receiveCompletion
            self.receiveCompletion = { _ in }
            
            // 当, 一个节点收到了 Cancel, 或者 Complete 的时候, 应该做好自己的资源的释放工作.
            // 当, 所有的节点, 都能做好自己的资源释放的时候, 各个节点完成自己的任务就可以了, 因为可以默认, 自己被调用的时候, 自己的上层或者下层, 都会完成自己层级的资源释放.
            withExtendedLifetime(receiveValue) {
                receiveValue = { _ in }
                lock.unlock()
            }
            // 真正调用存储的回调.
            receiveCompletion(completion)
        }
        
        // Cancel 的责任是, 资源释放, 必要要做的是, 要完成对于上游节点的 cancel 触发.
        // 这样, 这个链条才能有意义.
        public func cancel() {
            lock.lock()
            // 如果, 已经 Complete 了, 这里是不会有后续的操作的.
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            withExtendedLifetime((receiveValue, receiveCompletion)) {
                receiveCompletion = { _ in }
                receiveValue = { _ in }
                lock.unlock()
            }
            subscription.cancel()
        }
    }
}
