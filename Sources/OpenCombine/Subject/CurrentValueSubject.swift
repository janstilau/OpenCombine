/*
 A subject that wraps a single value and publishes a new element whenever the value changes.
 Declaration
 final class CurrentValueSubject<Output, Failure> where Failure : Error
 
 Overview
 Unlike PassthroughSubject, CurrentValueSubject maintains a buffer of the most recently published element.
 Calling send(_:) on a CurrentValueSubject also updates the current value, making it equivalent to updating the value directly.
 */

/// A subject that wraps a single value and publishes a new element whenever the value
/// changes.
// 初始化的时候, 必须要有一个数据, 每次更新, 都替换该数据. 这个 Subject 非常适合 UI 数据的更新, 因为他能提供 UI 数据. 并且在 attach 的时候, 就能够进行初始数据的发送.

/// Unlike `PassthroughSubject`, `CurrentValueSubject` maintains a buffer of the most
/// recently published element.

/// Calling `send(_:)` on a `CurrentValueSubject` also updates the current value, making
/// it equivalent to updating the `value` directly.

public final class CurrentValueSubject<Output, Failure: Error>: Subject {
    
    /*
     Combine 就是为了在多线程环境下进行的, 所以, 一定会有锁的存在.
     */
    private let subjectInnerLock = UnfairLock.allocate()
    
    private var isActive = true
    
    // 存储一下结束事件.
    // 在 Subject 接收到上游的结束事件的时候, 会将这个值进行存储.
    // 后续新的 Subscriber 来临的时候, 可以直接收到这个存储的事件.
    // 这个概念, 和 Promise 是一致的. 不过, Completion 的时候, 是不会存储 Result 的值的, 只是存储了 Complete 的状态.
    private var completion: Subscribers.Completion<Failure>?
    
    // 存储一下, 上游节点. 上游节点, 只会在 Deinit 的时候, 对于所有的上游节点进行 cancel.
    /*
     1. 如果, 这个 Subject 是一个单独没有共享的响应链路, 那么取消上游, 是整个响应链路取消. 没有问题, 因为下游节点已经取消了.
     2. 如果, 这个 Subject 所在链路在一个 Share 的 Dispatch 中, 那么取消仅仅是让自己所在的链路消失, Share 的整个 DisPatch 不受影响.
     */
    
    // 一个 Subject 对象, 可能会有很多的上游节点. 因为, 可能会有很多的信号, 触发 Object 的修改.
    // 一个 Subject 对象, 可能会有很多的下游节点. 每次自己修改之后, 都会把修改信号, 发送给所有的下游节点.
    private var upstreamSubscriptions: [Subscription] = []
    
    // 所以, 实际上, Subject 是天然的分发器.
    // 存储一下, 下游节点. 没有直接存储 Subsriber, 而是一个 Conduit 对象
    private var downstreams = ConduitList<Output, Failure>.empty
    
    // 真正存值的地方
    /*
     currentValue 的赋值, 不会引发信号的发送. 而暴露给外界的, 是 public var value: Output 这样的一个属性.
     value 的 set 中, 引起真正存储的变化, 和信号的发送.
     这是一个非常常见的设计.
     */
    private var currentValue: Output
    
    /// The value wrapped by this subject, published as a new element whenever it changes.
    //
    public var value: Output {
        get {
            subjectInnerLock.lock()
            defer { subjectInnerLock.unlock() }
            // 取值, 必须在锁的环境
            return currentValue
        }
        set {
            // 在 Value 的赋值语句中, 会触发后面的 send 操作.
            subjectInnerLock.lock()
            // 赋值, 必须在锁的环境, 并且触发后续的信号发送.
            currentValue = newValue
            sendValueAndConsumeLock(newValue)
        }
    }
    
    // 使用函数命令, 表明了在方法内部, 其实是处于 Lock 的状态, 需要在内部进行 unlock 的触发.
    private func sendValueAndConsumeLock(_ newValue: Output) {
        // 必须要做这样的判断. 因为 Subject 的各个函数, 其实是手动触发的.
        // 如果使用者 sendComplete 之后, 又进行了 send value, 就触发了已经完成了但是有进行 Send 的场景了.
        // 业务逻辑复杂了之后, 类的设计者应该保证自己类的健壮性.
        guard isActive else {
            subjectInnerLock.unlock()
            return
        }
        currentValue = newValue
        let downstreams = self.downstreams
        subjectInnerLock.unlock()
        
        // 给下游节点进行数据投喂的操作, 集中在这里.
        downstreams.forEach { conduit in
            conduit.offer(newValue)
        }
    }
    
    // CurrentObject, 一定是初始化的时候, 提供值.
    public init(_ value: Output) {
        self.currentValue = value
    }
    
    deinit {
        // Subject, 在响应链条中, 是作为尾节点存在的.
        // 所以, 它的消失, 应该影响到整个链条.
        // 整个 upstreamSubscriptions 仅仅在这里, 被使用到了.
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        subjectInnerLock.deallocate()
    }
    
    /*
     上游节点, 发送 Subscription 过来, 记录在自己缓存区里面.
     */
    // This call provides the Subject an opportunity to establish demand for any new upstream subscriptions.
    public func send(subscription: Subscription) {
        subjectInnerLock.lock()
        // 存储所有的上游节点. upstreamSubscriptions 在类内没有业务逻辑, 主要是为了在 Subject deinit 的时候, 进行上游节点的 cancel 处理.
        upstreamSubscriptions.append(subscription)
        subjectInnerLock.unlock()
        
        /*
         Subject, 是一个 Pivot
         作为尾结点, 收集上游节点的各种数据.
         作为头节点, 当自身的 Value 发生变化后, 给所有自己记录的 Subscriber 发送新的信号.
         
         它所管理的几条后续链条, 它所管理的 ConduiteList 是各个链条的起始节点
         这些各自独立的链条的 Demand, 是在 Subject 中独立进行的管理.
         作为上一段链条的终点, 它不做 Demand 管理, 上游 Publisher 的 Next 事件全部接受.
         但是转发个给下游节点的时候, 如果这个链路上的 Demand 不足, 那么这个链路, 就失去了 Current Value 的值.
         
         从这个意义上来说, Subject 是作为尾节点存在的, 就和 Sink 一样.
         */
        subscription.request(.unlimited)
    }
    
    /*
     当收到下游节点的 Subscriber 的时候, Subject 注册监听的逻辑.
     */
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        subjectInnerLock.lock()
        if isActive {
            // 作为头结点, 自己管理的各个子响应链条的挂载操作.
            let conduit = Conduit(parent: self, downstream: subscriber)
            downstreams.insert(conduit)
            subjectInnerLock.unlock()
            // 下游节点, 面对的 Subscription 其实这个 Conduit 对象.
            // 这个对象, 可以算作是 Privot 所管理的各个链条的头结点.
            subscriber.receive(subscription: conduit)
        } else {
            // 如果, Subject 已经接受过了结束事件.
            // 那么对于新的 Subscriber, 应该让他知道这件事.
            let completion = self.completion!
            subjectInnerLock.unlock()
            // 一定要给后续的节点, 发送一个 subscription. 因为并不知道, 后续节点, 会根据这个做什么处理.
            subscriber.receive(subscription: Subscriptions.empty)
            subscriber.receive(completion: completion)
        }
    }
    
    public func send(_ input: Output) {
        subjectInnerLock.lock()
        sendValueAndConsumeLock(input)
    }
    
    // 不论, Subject 作为多少条链条的终止节点, 只要有一条发送了 Completion, 都结束.
    public func send(completion: Subscribers.Completion<Failure>) {
        subjectInnerLock.lock()
        guard isActive else {
            subjectInnerLock.unlock()
            return
        }
        
        // 记录一下 Completion, 之后的 subscriber 可以直接使用.
        // active 和 completion 是绑定在一起的, 可以使用一个 Enum 来进行管理.
        isActive = false
        self.completion = completion
        
        // 将, 所有的下游节点, 进行了清空的操作.
        let downstreams = self.downstreams.take()
        subjectInnerLock.unlock()
        downstreams.forEach { conduit in
            conduit.finish(completion: completion)
        }
    }
    
    // 作为头结点, 所管理的各个子响应联调的卸载操作.
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        subjectInnerLock.lock()
        guard isActive else {
            subjectInnerLock.unlock()
            return
        }
        // 解除 Subject 和下游节点的关联关系.
        downstreams.remove(conduit)
        subjectInnerLock.unlock()
    }
}

// 这里面, 最最主要的, 应该就是 Demand 的管理相关的逻辑.
// 在 Combine 里面, Demande 管理, 使得各个 Producer 都应该考虑下, 是否应该创建一个自己的 Subscription, 来专门做这件事.
extension CurrentValueSubject {
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Failure
    {
        // 这里有强引用.
        // 这里的循环引用没有太大的含义, 主要是为了调用 CurrentValueSubject 的卸载方法.
        fileprivate var parent: CurrentValueSubject?
        
        // 在每个 Conduit 里面, 记录下游节点. 当上游节点发送数据过来的时候, 交给各个 Conduit 传递给后续节点上.
        fileprivate var downstream: Downstream?
        // 记录下游节点, 对于自己的需求. 这个类存在的最主要的原因.
        fileprivate var demand = Subscribers.Demand.none
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        // 记录, 当前自己是否可以向后传递的状态.
        private var deliveredCurrentValue = false
        
        fileprivate init(parent: CurrentValueSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 上游节点, 发送数据过来之后, forward 给下游节点.
        // 在这个函数内, 有着 Demand 的管理策略.
        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            
            // demand 的管理.
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            // 给下游节点喂食.
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            // demand 的管理.
            demand += newDemand
            lock.unlock()
        }
        
        override func finish(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard let downstream = self.downstream.take() else {
                lock.unlock()
                return
            }
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
            downstreamLock.lock()
            // 下游节点, 接收到 完成事件.
            downstream.receive(completion: completion)
            downstreamLock.unlock()
        }
        
        // Request, 可以算作是, 下游节点, 触发上游节点逻辑的起点.
        // 这里有一点, 就是如果原来是没有需求的, 现在变为了有需求的了, 那么要主动的将现在 Current 的值, 传递过去.
        // 这是 Current 具有缓存功能的体现.
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            if deliveredCurrentValue {
                // 管理 Demand 的值.
                self.demand += demand
                lock.unlock()
                return
            }
            
            // Hasn't yet delivered the current value
            
            self.demand += demand
            deliveredCurrentValue = true
            if let currentValue = self.parent?.value {
                self.demand -= 1
                lock.unlock()
                downstreamLock.lock()
                // 如果, 后续节点要值了, 那么主动的发送一下当前的值过去.
                let newDemand = downstream.receive(currentValue)
                downstreamLock.unlock()
                guard newDemand > 0 else { return }
                lock.lock()
                self.demand += newDemand
            }
            lock.unlock()
        }
        
        override func cancel() {
            lock.lock()
            if downstream.take() == nil {
                lock.unlock()
                return
            }
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }
        
        var description: String { return "CurrentValueSubject" }
        
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("parent", parent as Any),
                ("downstream", downstream as Any),
                ("demand", demand),
                ("subject", parent as Any)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
