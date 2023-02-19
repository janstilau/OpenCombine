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
    internal final var result: Output? // Result 会在每次 Receive Input 的时候, 由子类进行变化.
    
    // 闭包. 使用这个闭包, 在每次获取 input 之后, 更新 result 的值
    // 这个闭包的类型, 是每个子类, 定义的时候指定的.
    internal final let reduce: Reducer
    
    // 这个状态, 在所有的 Subscriber 里面, 都会有.
    private var status = SubscriptionStatus.awaitingSubscription
    
    // 作为, 一个 Subscription, 应该有 downstream 这个数据.
    private let downstream: Downstream
    
    private let innerLock = UnfairLock.allocate()

    // 如果, 下游节点调用了 RequestDemand, 这个值会设置为 True.
    private var downstreamRequested = false
    // 如果, 上游节点发送了 Complete 事件, 这个值会设置为 True.
    private var upstreamCompleted = false
    // 因为 Combine 是 Pull 的机制, 所以只有上面的两个值都是 true 的时候, 才会真正向后方发送数据.
    
    private var chainCancelled = false
    private var chainCompleted = false
    
    // 这些赋值, 都是必须的. 
    internal init(downstream: Downstream, initial: Output?, reduce: Reducer) {
        self.downstream = downstream
        self.initial = initial
        self.result = initial
        self.reduce = reduce
    }
    
    deinit {
        innerLock.deallocate()
    }
    
    // MARK: - Abstract methods
    
    // 当, 收到上游的新值后, 应该怎么处理.
    internal func receive(
        newValue: Input
    ) -> ReceiveValueCompletion<Void, Downstream.Failure> {
        abstractMethod()
    }
    
    internal var description: String {
        abstractMethod()
    }
    
    // MARK: - CustomReflectable
    
    internal var customMirror: Mirror {
        innerLock.lock()
        defer { innerLock.unlock() }
        
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
        guard !chainCancelled, !chainCompleted, !upstreamCompleted else {
            innerLock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        // ReduceProducer 有着固定的模式. 就是上游要 Complete 之后, 才能发送下游的数据.
        upstreamCompleted = true
        if downstreamRequested {
            self.chainCompleted = true
        }
        let completed = self.chainCompleted
        let result = self.result
        // 及时放开临界区, 然后由函数内的变量进行后续逻辑的触发.
        // 函数内的变量, 不会收到其他线程的访问.
        innerLock.unlock()
        
        if completed {
            sendResultAndFinish(result)
        }
    }
    
    /// - Precondition: `lock` is held.
    private func receiveFailure(_ failure: UpstreamFailure) {
        guard !chainCancelled, !chainCompleted, !upstreamCompleted else {
            innerLock.unlock()
            // This should never happen, because `receive(completion:)`
            // (from which this function is called) early exists if
            // `status` is `.terminal`.
            assertionFailure("The subscription should have been terminated by now")
            return
        }
        upstreamCompleted = true
        chainCompleted = true
        innerLock.unlock()
        downstream.receive(completion: .failure(failure as! Downstream.Failure))
    }
    
    // 可能是上游发送 Complete 事件到达这里, 也可能是 ReceiveInput 判断链条该结束了, 到达这里.
    private func sendResultAndFinish(_ result: Output?) {
        assert(chainCompleted && upstreamCompleted)
        if let result = result {
            _ = downstream.receive(result)
        }
        downstream.receive(completion: .finished)
    }
}

// 能够充当 Subscriber, 就是能够在响应者链路中, 作为上游节点的后续节点.
extension ReduceProducer: Subscriber {
    
    internal func receive(subscription: Subscription) {
        innerLock.lock()
        // 防卫式的判断.
        guard case .awaitingSubscription = status else {
            innerLock.unlock()
            subscription.cancel()
            return
        }
        // 存储, 上方传递过来的 subscription 对象 .
        status = .subscribed(subscription)
        innerLock.unlock()
        downstream.receive(subscription: self)
        
        // 自己, 作为 Subscriber, 要求上游节点发送数据, 尽量多发.
        // 这是没有问题的. 因为, Reduce 节点, 是需要上游节点 completion 之后, 才可以向后发送数据的.
        // 所以, 应该尽量向上进行数据的索取.
        subscription.request(.unlimited)
    }
    
    // 其实不是很明白, 为什么要上锁, 按照目前的设计, 应该就是一条链路各自的状态是分离的才对.
    // 因为上游可能是 Subject 这样的分发节点, 而 Subject 的上游则是多个源头, 每个源头都可以指定自己的运行环境.
    // 如果没有专门的进行运行环境的指定, 上游直接将值投喂给下游, 下游在调用 receive(_ input: Input) 的时候, 确实是会处于不同的环境中, 加锁是没有问题的.
    internal func receive(_ input: Input) -> Subscribers.Demand {
        innerLock.lock()
        guard case let .subscribed(subscription) = status else {
            innerLock.unlock()
            return .none
        }
        innerLock.unlock()
        
        switch self.receive(newValue: input) {
        case .continue:
            // newValue 的值没问题, 但是还没达到结束的状态. 还应该收集上游节点的数据.
            break
        case .finished:
            // 正常结束了. 该输出 result 的值给下游节点了.
            innerLock.lock()
            upstreamCompleted = true
            let downstreamRequested = self.downstreamRequested
            if downstreamRequested {
                // 根据, upstreamCompleted downstreamRequested 共同过来决定 Complete 的状态.
                chainCompleted = true
            }
            // 自身的状态改变. 不会在接受响应中的各种事件.
            status = .terminal
            let result = self.result
            innerLock.unlock()
            
            // 触发上游节点的取消动作.
            subscription.cancel()
            guard downstreamRequested else { break }
            // 这里体现了 Combine 的 Demand 管理的思想. 上游已经发送结束了, 但是如果下游还没有明确的表示, 自己想要这个数据, 那么还是不应该将 Result 的值, 发送给下游的节点.
            sendResultAndFinish(result)
        case let .failure(error):
            innerLock.lock()
            upstreamCompleted = true
            chainCompleted = true
            status = .terminal
            innerLock.unlock()
            
            // 触发上游节点的取消动作.
            subscription.cancel()
            // 如果, 发生了错误, 是不受下游的 Demand 管理的, 直接将错误发送给下游节点.
            downstream.receive(completion: .failure(error))
        }
        
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<UpstreamFailure>) {
        innerLock.lock()
        guard case .subscribed = status else {
            innerLock.unlock()
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
        innerLock.lock()
        guard !downstreamRequested, !chainCancelled, !chainCompleted else {
            innerLock.unlock()
            return
        }
        // 只有下游明确需要了 demand, 才进行最终的 Result 的发送.
        downstreamRequested = true
        
        if upstreamCompleted  {
            chainCompleted = true
            let result = self.result
            innerLock.unlock()
            sendResultAndFinish(result)
        } else {
            innerLock.unlock()
        }
    }
    
    internal func cancel() {
        innerLock.lock()
        guard case let .subscribed(subscription) = status else {
            innerLock.unlock()
            return
        }
        chainCancelled = true
        status = .terminal
        innerLock.unlock()
        subscription.cancel()
    }
}

extension ReduceProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
