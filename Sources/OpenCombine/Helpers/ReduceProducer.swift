
/// A helper class that acts like both subscriber and subscription.
///
/// Reduce-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).
///
/// Reduce-like operators include `Publishers.Reduce`, `Publishers.TryReduce`,
/// `Publishers.Count`, `Publishers.FirstWhere`, `Publishers.AllSatisfy` and more.
///
/// Subclasses must override the `receive(newValue:)` and `description`.


/// 充当订阅者和订阅的辅助类。
///
/// 类似于 `reduce` 的操作符向上游发布者（作为订阅者）和向下游订阅者（作为订阅）发送其 `Inner` 类的实例，
/// 该类是此类的子类。
///
/// 类似于 `reduce` 的操作符包括 `Publishers.Reduce`、`Publishers.TryReduce`、`Publishers.Count`、
/// `Publishers.FirstWhere`、`Publishers.AllSatisfy` 等等。
///
/// 子类必须重写 `receive(newValue:)` 和 `description`。
/*
 reduce 是一种高阶函数，通常用于将一个集合（比如数组）的所有元素通过某种规则进行累积，最终得到一个单一的结果。这函数的核心思想是将一个二元操作应用于集合中的元素，不断地累积结果。
 */

// Reduce, 一系列的值, 变为一个值的过程.
internal class ReduceProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Reducer>
// Reducer 是一个闭包. 所以其实是可以
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output
{
    // NOTE: This class has been audited for thread safety
    
    // MARK: - State
    
    internal final var result: Output?
    
    private let initial: Output?
    
    internal final let reduce: Reducer // reduce 在父类里面, 其实根本没有用到. 如何使用, 是各个子类根据自己传递的 block 的类型, 自己使用的. 
    
    private var status = SubscriptionStatus.awaitingSubscription
    
    private let downstream: Downstream
    
    private let lock = UnfairLock.allocate()
    
    private var downstreamRequested = false
    
    private var cancelled = false
    
    private var completed = false
    
    private var upstreamCompleted = false
    
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
    
    // 重构点.
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
    
    // ReduceProducer 的统一语义, 就是将一系列值进行变化, 最终生成一个 Result 的值.
    // 所以它只会在收到 complete 事件的时候, 才会发送这个数据.
    private func sendResultAndFinish(_ result: Output?) {
        assert(completed && upstreamCompleted)
        if let result = result {
            _ = downstream.receive(result)
        }
        downstream.receive(completion: .finished)
    }
    
    // MARK: -
}

extension ReduceProducer: Subscriber {
    // 惯例实现.
    internal func receive(subscription: Subscription) {
        lock.lock()
        guard case .awaitingSubscription = status else {
            lock.unlock()
            subscription.cancel()
            return
        }
        status = .subscribed(subscription)
        lock.unlock()
        downstream.receive(subscription: self)
        subscription.request(.unlimited)
    }
    
    internal func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        guard case let .subscribed(subscription) = status else {
            lock.unlock()
            return .none
        }
        lock.unlock()
        
        // Combine doesn't hold the lock when calling `receive(newValue:)`.
        //
        // This can lead to data races if the contract is violated
        // (like when we receive input from multiple threads simultaneously).
        
        // 不一定是上游发送了 Complete, 在各个真正的业务子类里面, 其实可以在 receive(_ input: Input) 提前完成 Complte 的. 比如, firstWhere, 在第一个满足需求的收到之后, 就会发送 reuslt 给下游.
        switch self.receive(newValue: input) {
        case .continue:
            break
        case .finished:
            lock.lock()
            upstreamCompleted = true
            let downstreamRequested = self.downstreamRequested
            if downstreamRequested {
                completed = true
            }
            status = .terminal
            let result = self.result
            lock.unlock()
            
            // 在过程中, 认为完毕了, 会调用上游节点的 cancel 方法.
            subscription.cancel()
            
            guard downstreamRequested else { break }
            
            sendResultAndFinish(result)
        case let .failure(error):
            lock.lock()
            upstreamCompleted = true
            completed = true
            status = .terminal
            lock.unlock()
            
            subscription.cancel()
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
