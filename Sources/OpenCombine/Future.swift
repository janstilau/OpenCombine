/// A publisher that eventually produces a single value and then finishes or fails.
/*
 这个类的使用场景, 就是单一 Value.
 但是因为实际上, 我们很多时候要监听的事件就是 single value. 所以该类的使用场景特别多.
 */
public final class Future<Output, Failure: Error>: Publisher {
    /// A type that represents a closure to invoke in the future, when an element or error
    /// is available.
    
    /// The promise closure receives one parameter:
    // a `Result` that contains either a single element published by a `Future`, or an error.
    public typealias Promise = (Result<Output, Failure>) -> Void
    
    // 实际上, 线程控制这个问题是不可避免的.
    private let internalLock = UnfairLock.allocate()
    
    // 存储, 所有的后方节点. Future 的信号产生, 或者已经产生后, 将所有的数据, 通过 downstreams 传递给后方节点.
    // 存储的策略, 和 Subject 里面的也是完全相同的.
    private var downstreams = ConduitList<Output, Failure>.empty
    
    // 和 Promise 里面概念一样, 当异步事件发生之后, 将该值存储到 result 里面.
    private var result: Result<Output, Failure>?
    
    /// Creates a publisher that invokes a promise closure when the publisher emits
    /// an element.
    /// - Parameter attemptToFulfill: A `Promise` that the publisher invokes when
    ///   the publisher emits an element or terminates with an error.
    // 这是一个饿汉式的触发场景. 所以在初始化的时候, 就进行了相关闭包的调用.
    // 因为 Result 的存储机制, 使得 闭包完成之后, 新添加的 Subscriber 也可以收获到正确的值.
    public init(
        _ attemptToFulfill: @escaping (@escaping Promise) -> Void
    ) {
        // 这种, 直接 Self.Method 的写法非常流行.
        attemptToFulfill(self.promise)
    }
    
    deinit {
        internalLock.deallocate()
    }
    
    /*
     在这里面, 进行自身 Result 状态的修改.
     */
    private func promise(_ result: Result<Output, Failure>) {
        internalLock.lock()
        guard self.result == nil else {
            // 这里确保了, 必须只有一次的 result 状态改变的机会.
            internalLock.unlock()
            return
        }
        // 存储, 最终异步闭包得到的结果.
        self.result = result
        // 拿到结果之后, 把所有的后方节点进行了删除.
        let downstreams = self.downstreams.take()
        // 尽量减少临界区的大小.
        internalLock.unlock()
        
        switch result {
        case .success(let output):
            // 其实就是 fullfil 了. offer 里面调用的就是 fullfil
            downstreams.forEach { $0.offer(output) }
        case .failure(let error):
            downstreams.forEach { $0.finish(completion: .failure(error)) }
        }
    }
    
    /*
     当有新的 Subscriber 的时候, 将值包装成为一个 Conduit 值, 存储到自己的 downstreams 当中.
     */
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        let conduit = Conduit(parent: self, downstream: subscriber)
        internalLock.lock()
        // 如果, 已经有了 Result 了, 那么直接是使用 result 来进行数据传递.
        if let result = self.result {
            // 这里为什么还要加入呢, 为了流量控制.
            // 在 request demand 的时候, 才会根据下游是否需要进行 result 的发送, 这和 Promise 的思想是不一样的.
            downstreams.insert(conduit)
            internalLock.unlock()
            subscriber.receive(subscription: conduit)
            // conduit.fulfill 会做相关的 DispatchTable 的管理工作.
            conduit.fulfill(result)
        } else {
            // 否则, 就是记录回调. 等待异步操作的结果.
            downstreams.insert(conduit)
            internalLock.unlock()
            subscriber.receive(subscription: conduit)
        }
    }
    
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        internalLock.lock()
        downstreams.remove(conduit)
        internalLock.unlock()
    }
}

extension Future {
    
    /*
     Conduit 管道.
     每一个 Conduit, 管理一个后续的响应链路.
     */
    // Conduit 是可以进行 Cancel 的.
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        private enum State {
            // 原来 enum 里面, 可以进行前缀的添加.
            case active(Downstream, hasAnyDemand: Bool)
            case terminal
            
            // enum 需要对外提供, 类型是 Optinal 的各种方便的 get 属性. 这已经可以算作是一个惯例了.
            var downstream: Downstream? {
                switch self {
                case .active(let downstream, hasAnyDemand: _):
                    return downstream
                case .terminal:
                    return nil
                }
            }
            
            var hasAnyDemand: Bool {
                switch self {
                case .active(_, let hasAnyDemand):
                    return hasAnyDemand
                case .terminal:
                    return false
                }
            }
        }
        
        private var parent: Future?
        
        private var state: State
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        fileprivate init(parent: Future, downstream: Downstream) {
            self.parent = parent
            self.state = .active(downstream, hasAnyDemand: false)
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 名称中, 增加当前运行环境的状态描述. 在方法内部, 不需要进行环境的判断.
        // 在方法调用者, 必须进行环境的维护.
        fileprivate func lockedFulfill(downstream: Downstream,
                                       result: Result<Output, Failure>) {
            switch result {
            case .success(let output):
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(error))
            }
        }
        
        fileprivate func fulfill(_ result: Result<Output, Failure>) {
            lock.lock()
            guard case let .active(downstream, hasAnyDemand) = state else {
                lock.unlock()
                return
            }
            // 如果, 后续节点没有 Demand 的需求, 不给后面发送数据.
            // 这里进行了流量的控制. 下游有需求上游才进行发送.
            if case .success = result, !hasAnyDemand {
                lock.unlock()
                return
            }
            
            state = .terminal
            let parent = self.parent.take()
            lock.unlock()
            
            downstreamLock.lock()
            lockedFulfill(downstream: downstream, result: result)
            downstreamLock.unlock()
            // 然后, 上级把自己移除了.
            parent?.disassociate(self)
        }
        
        override func offer(_ output: Output) {
            fulfill(.success(output))
        }
        
        override func finish(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                assertionFailure("unreachable")
            case .failure(let error):
                fulfill(.failure(error))
            }
        }
        
        // Demand 的值不用管, 必须 > 0 才可以. Demand 仅仅是表示, 后续节点想要多少, 并不是 Publisher 必须提供多少.
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            
            lock.lock()
            // 取值和状态判断在一起.
            guard case .active(let downstream, hasAnyDemand: _) = state else {
                lock.unlock()
                return
            }
            state = .active(downstream, hasAnyDemand: true)
            
            // 如果, 已经有了数据了, 那么后续的 request 的时候, 直接就把数据给他.
            // 这里没有对于 parent 进行上锁. 所以其实会有线程问题的.
            if let parent = parent, let result = parent.result {
                // If the promise is already resolved, send the result downstream
                // immediately
                state = .terminal
                self.parent = nil
                lock.unlock()
                downstreamLock.lock()
                lockedFulfill(downstream: downstream, result: result)
                downstreamLock.unlock()
                parent.disassociate(self)
            } else {
                lock.unlock()
            }
        }
        
        override func cancel() {
            lock.lock()
            switch state {
            case .active:
                state = .terminal
                let parent = self.parent.take()
                lock.unlock()
                parent?.disassociate(self)
            case .terminal:
                lock.unlock()
            }
        }
        
        
        
        
        var description: String { return "Future" }
        
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", state.downstream as Any),
                ("hasAnyDemand", state.hasAnyDemand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
