
/// A publisher that eventually produces a single value and then finishes or fails.
// 这是经常使用的一个 Publisher, 用来进行封装常见的闭包逻辑.
// Future 也是一个多节点的源头.
public final class Future<Output, Failure: Error>: Publisher {
    
    /// A type that represents a closure to invoke in the future, when an element or error
    /// is available.
    ///
    /// The promise closure receives one parameter: a `Result` that contains either
    /// a single element published by a `Future`, or an error.
    public typealias Promise = (Result<Output, Failure>) -> Void
    
    private let lock = UnfairLock.allocate()
    
    private var downstreams = ConduitList<Output, Failure>.empty
    
    private var result: Result<Output, Failure>?
    
    /// Creates a publisher that invokes a promise closure when the publisher emits
    /// an element.
    ///
    /// - Parameter attemptToFulfill: A `Promise` that the publisher invokes when
    ///   the publisher emits an element or terminates with an error.
    // attemptToFulfill 里面, 是异步方法, 然后最后调用 self.promise 来触发信号的发送.
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
        
        self.result = result
        // 这个 take 的逻辑, 可以多多使用. 
        let downstreams = self.downstreams.take()
        lock.unlock()
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
        if let result = self.result {
            downstreams.insert(conduit)
            lock.unlock()
            subscriber.receive(subscription: conduit)
            conduit.fulfill(result)
        } else {
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
                // 必然是, 一个数据, 一个 finish 的事件.
                _ = downstream.receive(output)
                downstream.receive(completion: .finished)
            case .failure(let error):
                downstream.receive(completion: .failure(error))
            }
        }
        
        // Future 会在有 result 还接到下游的时候, 触发这里
        // 也会在 promise 函数里面, 触发这里.
        // 但是下游接受数据, 是和 demand 相关的. 所以, conduit 里面, 会有这 demand 的管理. 
        fileprivate func fulfill(_ result: Result<Output, Failure>) {
            lock.lock()
            // case 判断 + 取值的逻辑.
            guard case let .active(downstream, hasAnyDemand) = state else {
                lock.unlock()
                return
            }
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
        
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard case .active(let downstream, hasAnyDemand: _) = state else {
                lock.unlock()
                return
            }
            state = .active(downstream, hasAnyDemand: true)
            
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
