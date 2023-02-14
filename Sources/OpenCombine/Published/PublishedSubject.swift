
// 这是一个引用类型.
// PublishedSubject 和 CurrentSubject 没有太大的区别.
// 最最主要的就是, 增加了 changePublisher, 需要在每次值改变的时候, 进行调用. 触发值改变的信号的发出.
internal final class PublishedSubject<Output>: Subject {
    
    // 不会失败. 这是一个 PropertyWrapper. 属性的赋值, 是不会有数据改变失败的情况发生的.
    internal typealias Failure = Never
    
    private let lock = UnfairLock.allocate()
    
    // 当前的值.
    private var currentValue: Output
    
    // 必须要有当前值.
    internal init(_ value: Output) {
        self.currentValue = value
    }
    
    // 记录了所有的上游节点.
    // 这只会在 @Publisher.property 在 func assign(to published: inout Published<Output>.PublishedPublisher) 的时候会用到.
    // 一般情况下, 我们直接修改该值, 是直接调用 send 方法.
    private var upstreamSubscriptions: [Subscription] = []
    // 记录了所有的下游节点.
    // 在 send 方法里面, 所有记录的 downstreams 会被使用到.
    private var downstreams = ConduitList<Output, Failure>.empty
    
    // 这个 Subject 存在的原因就在这里了, 存储了一个 ObservableObjectPublisher 
    private var changePublisher: ObservableObjectPublisher?
    
    internal var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentValue
        }
        set {
            // 值进行修改的时候, 在这里进行了修改.
            send(newValue)
        }
    }
    
    // 这个值, 会在 ObservableObject 中进行设置. 利用的是反射的机制.
    internal var objectWillChange: ObservableObjectPublisher? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return changePublisher
        }
        // 从 ObservableObject.swift 里面的实现, 可以看到是, 对于一个对象里面, 所有的 @Published 属性, 里面都会存储一个 ObservableObjectPublisher 对象
        set {
            lock.lock()
            defer { lock.unlock() }
            changePublisher = newValue
        }
    }
    
    // 和, CurrentObject 完全一直.
    deinit {
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }
    
    // 在 PublishedSubscriber 中会调用该方法, 也就是, 在将 @Published 当做 Subscriber 的时候, 会记录上游节点.
    // 平时的属性赋值, 是直接调用 send, 来触发 Subject 的后续.
    internal func send(subscription: Subscription) {
        lock.lock()
        // 存储上游节点.
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        subscription.request(.unlimited)
    }
    
    // 当, 使用 @Publisher 的 $, 来当做 Publisher 来注册后续的响应的时候, 会触发到这里.
    // 就是将后续节点, 当做 Subject 的一个分流节点.
    internal func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Never
    {
        lock.lock()
        let conduit = Conduit(parent: self, downstream: subscriber)
        // 存储, 下游节点. 增加了一层抽象. Conduit
        downstreams.insert(conduit)
        lock.unlock()
        // 下游, 是接收 Conduit 作为上游节点.
        subscriber.receive(subscription: conduit)
    }
    
    internal func send(_ input: Output) {
        lock.lock()
        let downstreams = self.downstreams
        lock.unlock()
        
        // 这个类存在的最大的意义, 就是 @Published 属性, 每次修改的时候,
        // 都会主动的触发存储的 changePublisher 的信号发送.
        objectWillChange?.send()
        
        // 然后, 才是真正的后续监听者, 收到发生改变的值.
        // 和, CurrentObject 完全一直.
        downstreams.forEach { conduit in
            conduit.offer(input)
        }
        lock.lock()
        // 在最后, 才进行值的存储.
        currentValue = input
        lock.unlock()
    }
    
    internal func send(completion: Subscribers.Completion<Never>) {
        fatalError("unreachable")
    }
    
    private func disassociate(_ conduit: ConduitBase<Output, Failure>) {
        lock.lock()
        downstreams.remove(conduit)
        lock.unlock()
    }
}

extension PublishedSubject {
    
    // Conduit
    private final class Conduit<Downstream: Subscriber>
    : ConduitBase<Output, Failure>,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Never
    {
        
        fileprivate var parent: PublishedSubject?
        
        fileprivate var downstream: Downstream?
        
        fileprivate var demand = Subscribers.Demand.none
        
        private var lock = UnfairLock.allocate()
        
        private var downstreamLock = UnfairRecursiveLock.allocate()
        
        private var deliveredCurrentValue = false
        
        fileprivate init(parent: PublishedSubject,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
            downstreamLock.deallocate()
        }
        
        // 在 Conduit 里面, 做了 Demand 的管理.
        override func offer(_ output: Output) {
            lock.lock()
            guard demand > 0, let downstream = self.downstream else {
                deliveredCurrentValue = false
                lock.unlock()
                return
            }
            demand -= 1
            deliveredCurrentValue = true
            lock.unlock()
            downstreamLock.lock()
            
            // 真正的向下游节点, 发送数据信息.
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            
            lock.lock()
            demand += newDemand
            lock.unlock()
        }
        
        // 完成, Subscription 的要求, 后续节点主动的调用下面两个接口.
        override func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let downstream = self.downstream else {
                lock.unlock()
                return
            }
            if deliveredCurrentValue {
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
                // 在, Request 里面, 也会触发相关的行为.
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
            if self.downstream == nil {
                lock.unlock()
                return
            }
            self.downstream = nil
            let parent = self.parent.take()
            lock.unlock()
            parent?.disassociate(self)
        }
        
        
        
        var description: String { return "PublishedSubject" }
        
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
