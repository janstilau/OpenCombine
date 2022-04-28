
/// A publisher that eventually produces a single value and then finishes or fails.

/*
 这个类的设计, 和 Promise 很像. 就是, 存储生成的结果, 然后后续的所有节点统一使用.
 一个缓存的机制.
 */
public final class Future<Output, Failure: Error>: Publisher {
    /// A type that represents a closure to invoke in the future, when an element or error
    /// is available.
    ///
    /// The promise closure receives one parameter:
    // a `Result` that contains either a single element published by a `Future`, or an error.
    public typealias Promise = (Result<Output, Failure>) -> Void
    
    private let lock = UnfairLock.allocate()
    
    // 存回调. 这里和 Promise 的概念, 就已经完全相同了.
    // 存储的策略, 和 Subject 里面的也是完全相同的.
    private var downstreams = ConduitList<Output, Failure>.empty
    
    // 和 Promise 里面概念一样, 当异步事件发生之后, 将该值存储到 result 里面.
    private var result: Result<Output, Failure>?
    
    /// Creates a publisher that invokes a promise closure when the publisher emits
    /// an element.
    ///
    /// - Parameter attemptToFulfill: A `Promise` that the publisher invokes when
    ///   the publisher emits an element or terminates with an error.
    // 这是一个饿汉式的触发场景. 所以在初始化的时候, 就进行了相关闭包的调用.
    // 因为 Result 的存储机制, 使得 闭包完成之后, 新添加的 Subscriber 也可以收获到正确的值.
    public init(
        _ attemptToFulfill: @escaping (@escaping Promise) -> Void
    ) {
        attemptToFulfill(self.promise)
    }
    
    deinit {
        lock.deallocate()
    }
    
    private func promise(_ result: Result<Output, Failure>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        // 存储, 最终异步闭包得到的结果.
        self.result = result
        let downstreams = self.downstreams.take()
        lock.unlock()
        
        // 然后, 将结果分发给各个后续节点.
        switch result {
        case .success(let output):
            downstreams.forEach { $0.offer(output) }
        case .failure(let error):
            downstreams.forEach { $0.finish(completion: .failure(error)) }
        }
    }
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        let conduit = Conduit(parent: self, downstream: subscriber)
        lock.lock()
        // 如果, 已经有了 Result 了, 那么直接是使用 result 来进行数据传递.
        if let result = self.result {
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
            // conduit.fulfill 会做相关的 DispatchTable 的管理工作.
            conduit.fulfill(result)
        } else {
            // 否则, 就是记录回调. 等待异步操作的结果.
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
        }
    }
    
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension Future {
    
    /*
     Conduit 管道.
     
     每一个 Conduit, 管理一个后续的响应链路.
     */
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        private enum State {
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
            if case .success = result, !hasAnyDemand {
                lock.unlock()
                return
            }
            
            state = .terminal
            lock.unlock()
            downstreamLock.lock()
            lockedFulfill(downstream: downstream, result: result)
            let parent = self.parent.take()
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
            guard case .active(let downstream, hasAnyDemand: _) = state else {
                lock.unlock()
                return
            }
            state = .active(downstream, hasAnyDemand: true)
            
            // 如果, 已经有了数据了, 那么后续的 request 的时候, 直接就把数据给他.
            if let parent = parent, let result = parent.result {
                // If the promise is already resolved, send the result downstream
                // immediately
                state = .terminal
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
