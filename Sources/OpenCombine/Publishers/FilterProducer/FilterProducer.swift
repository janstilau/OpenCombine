/// A helper class that acts like both subscriber and subscription.
// 这种一般都是 Operator 构建出来的对象.

/// Filter-like operators send an instance of their `Inner` class that is subclass
/// of this class to the upstream publisher (as subscriber) and
/// to the downstream subscriber (as subscription).

/// Filter-like operators include
/// `Publishers.Filter`,
/// `Publishers.RemoveDuplicates`,
/// `Publishers.PrefixWhile` and more.

/// Subclasses must override the `receive(newValue:)` and `description`.

// 将, Filter 相关的逻辑, 全部积累到了这里.
// 子类的差异, 仅仅在 func receive(newValue: Input) 的时候进行变化, 其他的时候, 其他时候的逻辑, 都可以公用
// 这是一个 Sink 对象, 不是一个 Publisher 对象

internal class FilterProducer<Downstream: Subscriber,
                              Input,
                              Output,
                              UpstreamFailure: Error,
                              Filter>
: CustomStringConvertible,
  CustomReflectable
where Downstream.Input == Output {
    // MARK: - State
    
    private enum State {
        case awaitingSubscription // 这个值没啥用, 就是逻辑上的补全.
        case connected(Subscription) // 真正有用的部分, 有着存贮上游节点的功效.
        case completed
    }
    
    /*
     Filter
     RemoveDuplicates
     PrefixWhile
     */
    internal final let valueJudgement: Filter
    
    // 后方节点对象. 这是节点的惯例存储.
    internal final let downstream: Downstream
    
    private let lock = UnfairLock.allocate()
    
    // 存储当前的状态, 包括了上游的节点 -- Subscription
    private var state = State.awaitingSubscription
    
    internal init(downstream: Downstream, filter: Filter) {
        self.downstream = downstream
        self.valueJudgement = filter
    }
    
    deinit {
        lock.deallocate()
    }
    
    // MARK: - Abstract methods
    
    /*
     FilterProducer 里面的逻辑, 麻烦的就在于过来一个值之后, 是否应该将这个值向后传递.
     其他的逻辑都都是可以复用的.
     所以这块逻辑变成了模板方法, 供子类进行自定义.
     */
    internal func receive(newValue: Input) -> ReceiveValueCompletion<Output?, Downstream.Failure> {
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

// Subscriber 的责任
extension FilterProducer: Subscriber {
    
    internal func receive(subscription: Subscription) {
        lock.lock()
        
        guard case .awaitingSubscription = state else {
            lock.unlock()
            subscription.cancel()
            return
        }
            
        // 使用 enum 的盒子属性, 对状态进行了更改, 同时, 存储了上游的 Subscription 节点.
        state = .connected(subscription)
        lock.unlock()
        
        // 直接将自己, 作为下游的上游节点, 进行了传递.
        // 惯例做法, 这样, 响应链条各个节点, 才可以循环引用.
        downstream.receive(subscription: self)
    }
    
    // 当, 收到上游节点的 Output 之后, 应该使用 Filter 进行过滤处理.
    // 具体过滤完, 应该执行什么节奏, Filter, Compact, RemoveDup 各有各的不同.
    // 这些各个子类, receive(newValue: Input) -> 中进行自定义.
    // 根据以上方法的结果, 后续逻辑是统一的.
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
            
            // 根据 receive(newValue 的结果, 来完成 Demand 的管理.
            switch receive(newValue: input) {
                // Continue, 表示响应链条还继续存在.
            case let .continue(output?):
                // 有值, 根据下游节点的 receive 来决定 demand
                // 可能不是很习惯, 但是这种 case 就是 optinal 的有值情况
                return downstream.receive(output)
            case .continue(nil):
                // 无值, 代表着这个值被过滤掉了, 向上游节点继续要一个数据.
                return .max(1)
            case .finished:
                // 在 PrefixWhile 的时候, 会出现这种情况.
                // 某些 Opertor 在 Receive input 的时候, 可以终止整个响应链条的进行.
                lock.lock()
                // 状态管理
                state = .completed
                lock.unlock()
                
                // 终止整个响应链条
                // 上游 cancel
                subscription.cancel()
                // 下游 Completion
                downstream.receive(completion: .finished)
            case let .failure(error):  // 出现了错误.
                lock.lock()
                state = .completed
                lock.unlock()
                
                // 终止整个响应链条.
                // 上游 cancel
                subscription.cancel()
                // 下游 cancel
                downstream.receive(completion: .failure(error))
            }
            // completion 和 failure 的逻辑是一样的, 不过是下游接收到的事件不同.
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
        case .connected: // 带有关联值的 case, 也可以直接这样的进行匹配.
            // 当, 接收到上游 cancel 的时候, 一定是上游已经 cancel 了.
            // 所以, 这里只用处理下游 cancel 就可以了.
            // 状态的变化, 其实就是当前节点的资源释放.
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
        // 状态管理. 释放资源.
        state = .completed
        lock.unlock()
        // 当调用到 cancel 的时候, 一定是下游节点触发的. 所以, 不用再次触发下游节点的 cancel.
        // 通知上游进行 cancel. 这是一个惯例
        subscription.cancel()
    }
}

extension FilterProducer: CustomPlaygroundDisplayConvertible {
    internal var playgroundDescription: Any { return description }
}
