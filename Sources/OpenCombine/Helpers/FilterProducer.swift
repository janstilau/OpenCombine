/// A helper class that acts like both subscriber and subscription.
///
/// Filter-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).
///
/// Filter-like operators include `Publishers.Filter`,
/// `Publishers.RemoveDuplicates`, `Publishers.PrefixWhile` and more.
///
/// Subclasses must override the `receive(newValue:)` and `description`.
internal class FilterProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Filter>
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output
{
    // MARK: - State
    
    private enum State {
        case awaitingSubscription
        case connected(Subscription)
        case completed
    }
    
    internal final let filter: Filter
    
    internal final let downstream: Downstream
    
    private let lock = UnfairLock.allocate()
    
    private var state = State.awaitingSubscription
    
    internal init(downstream: Downstream, filter: Filter) {
        self.downstream = downstream
        self.filter = filter
    }
    
    deinit {
        lock.deallocate()
    }
    
    // MARK: - Abstract methods
    
    // 这个方法, 不是用来返回 Demand 的, 而是返回 Demand 的方法里面, 要根据这个方法的返回值, 来决定后续.
    internal func receive(
        newValue: Input
    ) -> PartialCompletion<Output?, Downstream.Failure> {
        abstractMethod()
    }
    
    internal var description: String {
        abstractMethod()
    }
    
    // MARK: - CustomReflectable
    
    internal var customMirror: Mirror {
        let children = CollectionOfOne<Mirror.Child>(("downstream", downstream))
        return Mirror(self, children: children)
    }
}

extension FilterProducer: Subscriber {
    
    internal func receive(subscription: Subscription) {
        lock.lock()
        // 防卫式处理.
        guard case .awaitingSubscription = state else {
            lock.unlock()
            subscription.cancel()
            return
        }
        // 将上游的 subscription 进行了存储
        // 体现了 Enum 作为数据盒子的特点.
        state = .connected(subscription)
        lock.unlock()
        //
        downstream.receive(subscription: self)
    }
    
    internal func receive(_ input: Input) -> Subscribers.Demand {
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock() // 不应该出现的情况
            fatalError("Invalid state: Received value before receiving subscription")
        case .completed:
            lock.unlock() // 不应该出现的情况
        case let .connected(subscription):
            lock.unlock()
            
            // 这里可以看出, 为什么要存储 subscription 来了.
            // 需要有一个机制, 来通知上游你应该 Cancel 了.
            // 在 Rx 里面, Subscription 是存储了上游节点的 Subscription, 下层的 Cancel 会触发上层的 Cancel.
            // 在 Combine 里面, 则是要存储一下上层节点, 主动触发上层节点的 Cancel.
            // 同时, 给下游节点 ,发送 compelte 事件, 让下层节点释放资源.
            
            // 因为 Try 相关的 Operator, 可能会 throw, 所以在 Receive Value 里面, 要有这层逻辑 .
            switch receive(newValue: input) {
            case let .continue(output?):
                // 有值, 根据下游节点的 receive 来决定 demand/
                return downstream.receive(output)
            case .continue(nil):
                // 过滤掉了值, 再要一个.
                return .max(1)
            case .finished:
                lock.lock()
                // 状态管理
                state = .completed
                lock.unlock()
                // 上游 cancel
                subscription.cancel()
                // 下游 cancel
                downstream.receive(completion: .finished)
            case let .failure(error):
                lock.lock()
                state = .completed
                lock.unlock()
                subscription.cancel()
                downstream.receive(completion: .failure(error))
            }
        }
        
        return .none
    }
    
    internal func receive(completion: Subscribers.Completion<UpstreamFailure>) {
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock()
            fatalError("Invalid state: Received completion before receiving subscription")
        case .completed:
            lock.unlock()
            return
        case .connected:
            state = .completed
            lock.unlock()
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case let .failure(failure):
                downstream.receive(completion: .failure(failure as! Downstream.Failure))
            }
        }
    }
}

extension FilterProducer: Subscription {
    
    // 作为 Subscription, 下游节点会主动调用以下的方法 .
    internal func request(_ demand: Subscribers.Demand) {
        demand.assertNonZero()
        lock.lock()
        switch state {
        case .awaitingSubscription:
            lock.unlock()
            fatalError("Invalid state: Received request before sending subscription")
        case .completed:
            lock.unlock()
            return
        case let .connected(subscription):
            lock.unlock()
            // 就是将 Request 的需求, 传递给上游.
            subscription.request(demand)
        }
    }
    
    internal func cancel() {
        lock.lock()
        guard case let .connected(subscription) = state else {
            state = .completed
            lock.unlock()
            return
        }
        // 状态管理. 
        state = .completed
        lock.unlock()
        // 通知上游进行 cancel
        subscription.cancel()
    }
}

extension FilterProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
