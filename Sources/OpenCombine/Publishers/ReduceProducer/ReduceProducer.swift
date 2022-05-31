/// A helper class that acts like both subscriber and subscription.

/// Reduce-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).

/// Reduce-like operators include
/// `Publishers.Reduce`,
/// `Publishers.TryReduce`,
/// `Publishers.Count`,
/// `Publishers.FirstWhere`,
/// `Publishers.AllSatisfy` and more.
/// Subclasses must override the `receive(newValue:)` and `description`.

internal class ReduceProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Reducer>
// Reducer 是一个闭包. 这个闭包, 不是一个固定的类型, 应该有 SubClass 进行制定.
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output
{
    // NOTE: This class has been audited for thread safety
    
    // MARK: - State
    
    // 起始值.
    private let initial: Output?
    
    // 结束值.
    internal final var result: Output?
    
    // 闭包. 使用这个闭包, 在每次获取 input 之后, 更新 result 的值
    // 这个闭包的类型, 是每个子类, 定义的时候指定的.
    internal final let reduce: Reducer
    
    // 这个状态, 在所有的 Subscriber 里面, 都会有.
    private var status = SubscriptionStatus.awaitingSubscription
    
    // 作为, 一个 Subscription, 应该有 downstream 这个数据.
    private let downstream: Downstream
    
    private let lock = UnfairLock.allocate()

    // 如果, 下游节点调用了 RequestDemand, 这个值会设置为 True.
    private var downstreamRequested = false
    // 如果, 上游节点发送了 Complete 事件, 这个值会设置为 True.
    private var upstreamCompleted = false
    // 因为 Combine 是 Pull 的机制, 所以只有上面的两个值都是 true 的时候, 才会真正向后方发送数据.
    
    private var cancelled = false
    
    private var completed = false
    
    // 这些赋值, 都是必须的. 
    internal init(downstream: Downstream, initial: Output?, reduce: Reducer) {
        self.downstream = downstream
        self.initial = initial
        self.result = initial
        self.reduce = reduce
    }
    
    deinit {
        lock.deallocate()
    }
    
    // MARK: - Abstract methods
    
    // 当, 收到上游的新值后, 应该怎么处理.
    internal func receive(
        newValue: Input
    ) -> PartialCompletion<Void, Downstream.Failure> {
        abstractMethod()
    }
    
    internal var description: String {
        abstractMethod()
    }
    
    // MARK: - CustomReflectable
    
    internal var customMirror: Mirror {
        lock.lock()
        defer { lock.unlock() }
        
        let children: [Mirror.Child] = [
            ("downstream", downstream),
            ("result", result as Any),
            ("initial", initial as Any),
            ("status", status)
        ]
        return Mirror(self, children: children)
    }
    
    // MARK: - Private
    
    /// - Precondition: `lock` is held.
    private func receiveFinished() {
        guard !cancelled, !completed, !upstreamCompleted else {
            lock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        // ReduceProducer 有着固定的模式. 就是上游要 Complete 之后, 才能发送下游的数据.
        upstreamCompleted = true
        if downstreamRequested {
            self.completed = true
        }
        let completed = self.completed
        let result = self.result
        lock.unlock()
        
        if completed {
            sendResultAndFinish(result)
        }
    }
    
    /// - Precondition: `lock` is held.
    private func receiveFailure(_ failure: UpstreamFailure) {
        guard !cancelled, !completed, !upstreamCompleted else {
            lock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        upstreamCompleted = true
        completed = true
        lock.unlock()
        downstream.receive(completion: .failure(failure as! Downstream.Failure))
    }
    
    private func sendResultAndFinish(_ result: Output?) {
        assert(completed && upstreamCompleted)
        if let result = result {
            _ = downstream.receive(result)
        }
        downstream.receive(completion: .finished)
    }
}

// 能够充当 Subscriber, 就是能够在响应者链路中, 作为上游节点的后续节点.
extension ReduceProducer: Subscriber {
    
    internal func receive(subscription: Subscription) {
        lock.lock()
        // 防卫式的判断.
        guard case .awaitingSubscription = status else {
            lock.unlock()
            subscription.cancel()
            return
        }
        // 存储, 上方传递过来的 subscription 对象 .
        status = .subscribed(subscription)
        lock.unlock()
        // 自己, 作为 subscription, 接受下游节点的 RequestDemand, Cancel 请求.
        downstream.receive(subscription: self)
        // 自己, 作为 Subscriber, 要求上游节点发送数据, 尽量多发.
        // 这是没有问题的. 因为, Reduce 节点, 是需要上游节点 completion 之后, 才可以向后发送数据的.
        // 所以, 应该尽量向上进行数据的索取.
        subscription.request(.unlimited)
    }
    
    // 之所以, 需要存储 subscription, 就是在 Receive 的时候.
    // 在 Reduce 的节点里面, 可能会在接受到上游节点的数据之后, 直接进行上游的取消, 下游的取消.
    // 这个时候, 就得保存上游的节点, 才能完成这样的操作.
    internal func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        guard case let .subscribed(subscription) = status else {
            lock.unlock()
            return .none
        }
        lock.unlock()
        
        // 在子类的 receive(newValue 中, 根据 Reduce Block, 现有的 Result, 新来的 Input 值, 对 Result 进行更新.
        // 并且, 输出是否结束的返回值.
        // 外界根据输出的返回值, 来判断是否使得当前的响应链进行 cancel.
        switch self.receive(newValue: input) {
        case .continue:
            // newValue 的值没问题, 但是还没达到结束的状态. 还应该收集上游节点的数据.
            break
        case .finished:
            // 正常结束了. 该输出 result 的值给下游节点了.
            lock.lock()
            upstreamCompleted = true
            let downstreamRequested = self.downstreamRequested
            if downstreamRequested {
                // 根据, upstreamCompleted downstreamRequested 共同过来决定 Complete 的状态.
                completed = true
            }
            // 自身的状态改变. 不会在接受响应中的各种事件.
            status = .terminal
            let result = self.result
            lock.unlock()
            // 触发上游节点的取消动作.
            subscription.cancel()
            guard downstreamRequested else { break }
            
            // 这里体现了 Combine 的 Demand 管理的思想. 上游已经发送结束了, 但是如果下游还没有明确的表示, 自己想要这个数据, 那么还是不应该将 Result 的值, 发送给下游的节点.
            sendResultAndFinish(result)
        case let .failure(error):
            lock.lock()
            upstreamCompleted = true
            completed = true
            status = .terminal
            lock.unlock()
            // 触发上游节点的取消动作.
            subscription.cancel()
            // 如果, 发生了错误, 是不受下游的 Demand 管理的, 直接将错误发送给下游节点.
            downstream.receive(completion: .failure(error))
        }
        
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<UpstreamFailure>) {
        lock.lock()
        guard case .subscribed = status else {
            lock.unlock()
            return
        }
        status = .terminal
        switch completion {
        case .finished:
            receiveFinished()
        case let .failure(error):
            receiveFailure(error)
        }
    }
}

extension ReduceProducer: Subscription {
    
    internal func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        guard !downstreamRequested, !cancelled, !completed else {
            lock.unlock()
            return
        }
        // 监听下游节点的 Demand 请求,
        // 如果下游节点有需求, 那么应该记录状态.
        // 当, 上游结束, 下游有需求的时候, 触发 sendResultAndFinish 的操作.
        downstreamRequested = true
        
        guard upstreamCompleted else  {
            lock.unlock()
            return
        }
        completed = true
        let result = self.result
        lock.unlock()
        sendResultAndFinish(result)
    }
    
    internal func cancel() {
        lock.lock()
        guard case let .subscribed(subscription) = status else {
            lock.unlock()
            return
        }
        cancelled = true
        status = .terminal
        lock.unlock()
        subscription.cancel()
    }
}

extension ReduceProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
