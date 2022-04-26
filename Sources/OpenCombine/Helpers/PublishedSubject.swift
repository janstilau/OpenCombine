//
//  PublishedSubject.swift
//  
//
//  Created by Sergej Jaskiewicz on 29.10.2020.
//

internal final class PublishedSubject<Output>: Subject {
    
    internal typealias Failure = Never
    
    private let lock = UnfairLock.allocate()
    
    
    private var currentValue: Output
    
    // 记录了所有的上游节点.
    // 在 Rx 里面, 上游节点, 是不用记录的. 因为在 Rx 里面, 循环引用是建立在 sinkDisposer 和 sink 之间的.
    private var upstreamSubscriptions: [Subscription] = []
    
    // 记录了所有的下游节点.
    private var downstreams = ConduitList<Output, Failure>.empty
    
    private var hasAnyDownstreamDemand = false
    
    private var changePublisher: ObservableObjectPublisher?
    
    internal var value: Output {
        get {
            lock.lock()
            defer { lock.unlock() }
            return currentValue
        }
        set {
            send(newValue)
        }
    }
    
    internal var objectWillChange: ObservableObjectPublisher? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return changePublisher
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            changePublisher = newValue
        }
    }
    
    // 必须要有当前值.
    internal init(_ value: Output) {
        self.currentValue = value
    }
    
    deinit {
        // 当, Subject 消亡的时候, 让所有的上游节点 cancel ???
        // 感觉这里有问题. 不应该这样做.
        for subscription in upstreamSubscriptions {
            subscription.cancel()
        }
        lock.deallocate()
    }
    
    internal func send(subscription: Subscription) {
        lock.lock()
        // 存储上游节点.
        upstreamSubscriptions.append(subscription)
        lock.unlock()
        subscription.request(.unlimited)
    }
    
    internal func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Downstream.Input == Output, Downstream.Failure == Never
    {
        lock.lock()
        let conduit = Conduit(parent: self, downstream: subscriber)
        // 存储, 下游节点. 增加了一层抽象. Conduit
        downstreams.insert(conduit)
        lock.unlock()
        subscriber.receive(subscription: conduit)
    }
    
    internal func send(_ input: Output) {
        lock.lock()
        let downstreams = self.downstreams
        let changePublisher = self.changePublisher
        lock.unlock()
        // 通知一下, 当前已经发生了变化.
        // 这主要是为了通知监听该 Subject 的数据.
        changePublisher?.send()
        downstreams.forEach { conduit in
            conduit.offer(input)
        }
        lock.lock()
        // 存储一下当前值.
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
            let newDemand = downstream.receive(output)
            downstreamLock.unlock()
            guard newDemand > 0 else { return }
            lock.lock()
            demand += newDemand
            lock.unlock()
        }
        
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
