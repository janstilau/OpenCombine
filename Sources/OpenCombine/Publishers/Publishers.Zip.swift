
#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

/*
 Use Publishers.Zip to combine the latest elements from two publishers and emit a tuple to the downstream. The returned publisher waits until both publishers have emitted an event, then delivers the oldest unconsumed event from each publisher together as a tuple to the subscriber.
 Much like a zipper or zip fastener on a piece of clothing pulls together rows of teeth to link the two sides, Publishers.Zip combines streams from two different publishers by linking pairs of elements from each side.
 If either upstream publisher finishes successfully or fails with an error, so too does the zipped publisher.
 */
// Zip Publihser, 主要用来进行数据的收集工作
extension Publishers {
    
    /// A publisher created by applying the zip function to two upstream publishers.
    // 必须, UpstreamA UpstreamB 的 Failure 是一致的.
    // 而 Output, 则是各个 Publisher 的 Output 组成的 Tuple
    public struct Zip<UpstreamA: Publisher, UpstreamB: Publisher>: Publisher
    where UpstreamA.Failure == UpstreamB.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (UpstreamA.Output, UpstreamB.Output)
        
        /// The kind of errors this publisher might publish.
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure
        
        public let a: UpstreamA
        
        public let b: UpstreamB
        
        public init(_ a: UpstreamA, _ b: UpstreamB) {
            self.a = a
            self.b = b
        }
        
        /// This function is called to attach the specified `Subscriber` to this
        ///  `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        
        // Zip 是一个 Container, 所以其实他并不需要, Upstream 进行 Subscribe.
        public func receive<Downstream: Subscriber>(subscriber: Downstream) where
        UpstreamB.Failure == Downstream.Failure,
        Downstream.Input == (UpstreamA.Output, UpstreamB.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b)
        }
    }
    
    /// A publisher created by applying the zip function to three upstream publishers.
    public struct Zip3<UpstreamA: Publisher,
                       UpstreamB: Publisher,
                       UpstreamC: Publisher>
    : Publisher
    where UpstreamA.Failure == UpstreamB.Failure,
          UpstreamB.Failure == UpstreamC.Failure
    {
        /// The kind of values published by this publisher.
        public typealias Output = (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure
        
        public let a: UpstreamA
        
        public let b: UpstreamB
        
        public let c: UpstreamC
        
        public init(_ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC) {
            self.a = a
            self.b = b
            self.c = c
        }
        
        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream>(subscriber: Downstream)
        where Downstream: Subscriber,
              UpstreamC.Failure == Downstream.Failure,
        // swiftlint:disable:next large_tuple
        Downstream.Input == (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b, c)
        }
    }
    
    /// A publisher created by applying the zip function to four upstream publishers.
    public struct Zip4<
        UpstreamA: Publisher,
        UpstreamB: Publisher,
        UpstreamC: Publisher,
        UpstreamD: Publisher
    >: Publisher where
    UpstreamA.Failure == UpstreamB.Failure,
    UpstreamB.Failure == UpstreamC.Failure,
    UpstreamC.Failure == UpstreamD.Failure
    {
        
        /// The kind of values published by this publisher.
        public typealias Output = (
            UpstreamA.Output,
            UpstreamB.Output,
            UpstreamC.Output,
            UpstreamD.Output)
        
        /// The kind of errors this publisher might publish.
        ///
        /// Use `Never` if this `Publisher` does not publish errors.
        public typealias Failure = UpstreamA.Failure
        
        public let a: UpstreamA
        
        public let b: UpstreamB
        
        public let c: UpstreamC
        
        public let d: UpstreamD
        
        public init(_ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC, _ d: UpstreamD) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }
        
        /// This function is called to attach the specified `Subscriber` to this
        /// `Publisher` by `subscribe(_:)`
        ///
        /// - SeeAlso: `subscribe(_:)`
        /// - Parameters:
        ///     - subscriber: The subscriber to attach to this `Publisher`.
        ///                   once attached it can begin to receive values.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where UpstreamD.Failure == Downstream.Failure,
        // swiftlint:disable:next large_tuple
        Downstream.Input == (
            UpstreamA.Output,
            UpstreamB.Output,
            UpstreamC.Output,
            UpstreamD.Output)
        {
            _ = Inner<Downstream>(downstream: subscriber, a, b, c, d)
        }
    }
}

extension Publisher {
    // Zip 的 Publisher 方法, 隐藏真正的 Publihser 的生成.
    /// Combine elements from another publisher and deliver pairs of elements as tuples.
    
    /// The returned publisher waits until both publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher together as a tuple to
    /// the subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    ///  emits event `c`, the zip publisher emits the tuple `(a, c)`. It won’t emit a
    ///   tuple with event `b` until `P2` emits another event.
    /// If either upstream publisher finishes successfuly or fails with an error, the
    /// zipped publisher does the same.
    ///
    /// - Parameter other: Another publisher.
    /// - Returns: A publisher that emits pairs of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other>(_ other: Other) -> Publishers.Zip<Self, Other>
    where Other: Publisher, Self.Failure == Other.Failure
    {
        return Publishers.Zip(self, other)
    }
    
    /// Combine elements from another publisher and deliver a transformed output.
    ///
    /// The returned publisher waits until both publishers have emitted an event, then
    ///  delivers the oldest unconsumed event from each publisher together as a tuple to
    ///  the subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits event `c`, the zip publisher emits the tuple `(a, c)`. It won’t emit a tuple
    /// with event `b` until `P2` emits another event.
    /// If either upstream publisher finishes successfuly or fails with an error, the
    /// zipped publisher does the same.
    ///
    /// - Parameter other: Another publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                and returns a new value to publish.
    /// - Returns: A publisher that emits pairs of elements from the upstream publishers
    ///            as tuples.
    public func zip<Other, Result>(
        _ other: Other,
        _ transform: @escaping (Self.Output, Other.Output) -> Result)
    -> Publishers.Map<Publishers.Zip<Self, Other>, Result>
    where Other: Publisher, Self.Failure == Other.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip(self, other), transform: transform)
    }
    
    /// Combine elements from two other publishers and deliver groups of elements as
    /// tuples.
    ///
    /// The returned publisher waits until all three publishers have emitted an event,
    /// then delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the event `e`, the zip
    /// publisher emits the tuple `(a, c, e)`. It won’t emit a tuple with elements `b` or
    /// `d` until `P3` emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2>(_ publisher1: Other1, _ publisher2: Other2)
    -> Publishers.Zip3<Self, Other1, Other2>
    where Other1: Publisher,
Other2: Publisher,
    Self.Failure == Other1.Failure,
    Other1.Failure == Other2.Failure
    {
        return Publishers.Zip3(self, publisher1, publisher2)
    }
    
    /// Combine elements from two other publishers and deliver a transformed output.
    ///
    /// The returned publisher waits until all three publishers have emitted an event,
    /// then delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the event `e`, the zip
    /// publisher emits the tuple `(a, c, e)`. It won’t emit a tuple with elements `b` or
    /// `d` until `P3` emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                 and returns a new value to publish.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Result>(
        _ publisher1: Other1,
        _ publisher2: Other2,
        _ transform: @escaping (Self.Output, Other1.Output, Other2.Output) -> Result)
    -> Publishers.Map<Publishers.Zip3<Self, Other1, Other2>, Result>
    where Other1: Publisher,
Other2: Publisher,
    Self.Failure == Other1.Failure,
    Other1.Failure == Other2.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip3(self, publisher1, publisher2),
                              transform: transform)
    }
    
    /// Combine elements from three other publishers and deliver groups of elements as
    /// tuples.
    ///
    /// The returned publisher waits until all four publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the elements `e` and `f`, and
    /// publisher `P4` emits the event `g`, the zip publisher emits the tuple
    /// `(a, c, e, g)`. It won’t emit a tuple with elements `b`, `d`, or `f` until `P4`
    /// emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Other3>(_ publisher1: Other1,
                                            _ publisher2: Other2,
                                            _ publisher3: Other3)
    -> Publishers.Zip4<Self, Other1, Other2, Other3>
    where Other1: Publisher,
Other2: Publisher,
Other3: Publisher,
    Self.Failure == Other1.Failure,
    Other1.Failure == Other2.Failure,
    Other2.Failure == Other3.Failure
    {
        return Publishers.Zip4(self, publisher1, publisher2, publisher3)
    }
    
    
    /// Combine elements from three other publishers and deliver a transformed output.
    ///
    /// The returned publisher waits until all four publishers have emitted an event, then
    /// delivers the oldest unconsumed event from each publisher as a tuple to the
    /// subscriber.
    /// For example, if publisher `P1` emits elements `a` and `b`, and publisher `P2`
    /// emits elements `c` and `d`, and publisher `P3` emits the elements `e` and `f`, and
    /// publisher `P4` emits the event `g`, the zip publisher emits the tuple
    /// `(a, c, e, g)`. It won’t emit a tuple with elements `b`, `d`, or `f` until `P4`
    /// emits another event.
    /// If any upstream publisher finishes successfuly or fails with an error, the zipped
    /// publisher does the same.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher.
    ///   - publisher2: A third publisher.
    ///   - publisher3: A fourth publisher.
    ///   - transform: A closure that receives the most recent value from each publisher
    ///                 and returns a new value to publish.
    /// - Returns: A publisher that emits groups of elements from the upstream publishers
    ///             as tuples.
    public func zip<Other1, Other2, Other3, Result>(
        _ publisher1: Other1,
        _ publisher2: Other2,
        _ publisher3: Other3,
        _ transform: @escaping (Self.Output, Other1.Output, Other2.Output, Other3.Output)
        -> Result)
    -> Publishers.Map<Publishers.Zip4<Self, Other1, Other2, Other3>, Result>
    where Other1: Publisher,
Other2: Publisher,
Other3: Publisher,
    Self.Failure == Other1.Failure,
    Other1.Failure == Other2.Failure,
    Other2.Failure == Other3.Failure
    {
        return Publishers.Map(upstream: Publishers.Zip4(self,
                                                        publisher1,
                                                        publisher2,
                                                        publisher3),
                              transform: transform)
    }
}

extension Publishers.Zip {
    // 真正的 Subscription 对象.
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
    where Downstream.Failure == Failure,
          Downstream.Input == (UpstreamA.Output, UpstreamB.Output)
    {
        // 在, Zip 的 Subscription 的构造函数里面, 将对应的 ChildSubscriber 生成了.
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)
        
        init(downstream: Downstream, _ a: UpstreamA, _ b: UpstreamB) {
            super.init(downstream: downstream)
            
            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
        }
        
        override fileprivate var upstreamSubscriptions: [ChildSubscription] {
            return [aSubscriber, bSubscriber]
        }
        
        override fileprivate func dequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(), bSubscriber.dequeueValue())
        }
    }
}

extension Publishers.Zip3 {
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
    where Downstream.Failure == Failure,
          Downstream.Input == (UpstreamA.Output, UpstreamB.Output, UpstreamC.Output)
    {
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)
        private lazy var cSubscriber = ChildSubscriber<UpstreamC, Downstream>(self, 2)
        
        init(downstream: Downstream, _ a: UpstreamA, _ b: UpstreamB, _ c: UpstreamC) {
            super.init(downstream: downstream)
            
            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
            c.subscribe(cSubscriber)
        }
        
        override fileprivate var upstreamSubscriptions: [ChildSubscription] {
            return [aSubscriber, bSubscriber, cSubscriber]
        }
        
        override fileprivate func dequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(),
                    bSubscriber.dequeueValue(),
                    cSubscriber.dequeueValue())
        }
    }
}

// 各种 Zip, 都有着固定的实现的逻辑.
extension Publishers.Zip4 {
    private class Inner<Downstream: Subscriber>: InnerBase<Downstream>
    where Downstream.Failure == Failure,
          Downstream.Input == (
            UpstreamA.Output,
            UpstreamB.Output,
            UpstreamC.Output,
            UpstreamD.Output)
    {
        private lazy var aSubscriber = ChildSubscriber<UpstreamA, Downstream>(self, 0)
        private lazy var bSubscriber = ChildSubscriber<UpstreamB, Downstream>(self, 1)
        private lazy var cSubscriber = ChildSubscriber<UpstreamC, Downstream>(self, 2)
        private lazy var dSubscriber = ChildSubscriber<UpstreamD, Downstream>(self, 3)
        
        init(downstream: Downstream,
             _ a: UpstreamA,
             _ b: UpstreamB,
             _ c: UpstreamC,
             _ d: UpstreamD)
        {
            super.init(downstream: downstream)
            
            a.subscribe(aSubscriber)
            b.subscribe(bSubscriber)
            c.subscribe(cSubscriber)
            d.subscribe(dSubscriber)
        }
        
        override fileprivate var upstreamSubscriptions: [ChildSubscription] {
            return [aSubscriber, bSubscriber, cSubscriber, dSubscriber]
        }
        
        override fileprivate func dequeueValue() -> Downstream.Input {
            return (aSubscriber.dequeueValue(),
                    bSubscriber.dequeueValue(),
                    cSubscriber.dequeueValue(),
                    dSubscriber.dequeueValue())
        }
    }
}

private class InnerBase<Downstream: Subscriber>: CustomStringConvertible {
    let description = "Zip"
    
    private let lock = UnfairRecursiveLock.allocate()
    
    private let downstream: Downstream
    private var downstreamDemand = Subscribers.Demand.none
    private var valueIsBeingProcessed = false
    private var value: Downstream.Input?
    private var isFinished = false
    
    // The following two pieces of state are a hacky implementation of subtle Apple
    // concurrency behaviors. Specifically, when Zip is processing an upstream child value
    // and sending a resulting value downstream, multiple behaviors are changed.
    //  1. If a downstream demand request comes in during this period, the demand request
    //     for that specific triggering upstream child will be communiated via the result
    //     of `.receive(_ input:)` INSTEAD of a later `.request(_ demand:)` call.
    //     (AppleRef: 001)
    //  2. If an upstream `.finished` comes in during this time period, the "finished
    //     asssessment check" (AppleRef: 002) is skipped.
    // If an upstream value is being processed when a downstream demand request comes in,
    // the demand for that specfic upstream child will be communiated via the result
    // of `.receive(_ input:)` INSTEAD of a later `.request(_ demand:)` call.
    private final var processingValueForChild: ChildSubscription?
    private final var demandReceivedWhileProcessing: Subscribers.Demand?
    
    init(downstream: Downstream) {
        self.downstream = downstream
    }
    
    deinit {
        lock.deallocate()
    }
    
    fileprivate var upstreamSubscriptions: [ChildSubscription] {
        abstractMethod()
    }
    
    fileprivate func dequeueValue() -> Downstream.Input {
        abstractMethod()
    }
    
    // ChildReceiver 会触发该方法, 当原有的 Publihser, 发送 ChildSubscription 给 ChildReceiver 的时候触发.
    // 主要逻辑在于, 修改 ChildSubscription 的状态, 以及判断是否所有的节点都已经收到了上游节点, 如果是的话, 给 Zip 的下游节点, 发送 Zip 节点为 Subscription.
    fileprivate final func receivedSubscription(for child: ChildSubscription) {
        lock.lock()
        // Child 的状态改变, 感觉还是应该放到自己的类里面比较合适.
        child.state = .active
        // 当, 所有的中转 Subscription 都已经接收到了上级的 Subscription 之后, 才将自己传递给后方节点.
        // 不然, 后方节点 Request Demand 没有太大的意义. 因为 Zip 的定义是, 必须所有的中转节点, 都有数据, 才会给后方发送数据.
        let sendSubscriptionDownstream = upstreamSubscriptions
            .filter { $0.state == .waitingForSubscription }
            .isEmpty
        lock.unlock()
        
        if sendSubscriptionDownstream {
            self.sendSubscriptionDownstream()
        }
    }
    
    // 子节点, 收取到 Value 之后, 调用 Zip 管理者的该逻辑.
    // lockedStoreValue 之所以要传递过来, 是因为, 要在统一的锁的管理下.
    fileprivate final func receivedChildValue(
        child: ChildSubscription,
        _ lockedStoreValue: () -> Void
    ) -> Subscribers.Demand {
        lock.lock()
        lockedStoreValue()
        defer {
            checkShouldFinish()
            lock.unlock()
        }
        
        // 当, 子节点收到数据之后, 判断是否所有的节点都有数据了.
        // 如果是的话, 抽取数据, 然后发送给后方 .
        if let dequeuedValue = maybeDequeueValue() {
            value = dequeuedValue
            assert(processingValueForChild == nil)
            processingValueForChild = child
            valueIsBeingProcessed = true
            return processValue() ?? .none
        } else {
            return .none
        }
    }
    
    fileprivate final func receivedCompletion(
        _ completion: Subscribers.Completion<Downstream.Failure>,
        forChild child: ChildSubscription) {
        switch completion {
        case .failure:
            // 如果, 是出错了, 那么直接就传输给后续的节点.
            downstream.receive(completion: completion)
            lock.lock()
            child.state = .failed
            let subscriptionsToCancel = upstreamSubscriptions
            lock.unlock()
            // 并且, 通知所有的子节点, 进行取消的操作.
            subscriptionsToCancel.forEach { $0.cancel() }
        case .finished:
            lock.lock()
            child.state = .finished
            if !valueIsBeingProcessed {
                valueIsBeingProcessed = true
                if processingValueForChild == nil &&
                    !areMoreValuesPossible &&
                    !isFinished {
                    sendFinishDownstream()
                } else {
                    processValue()
                }
            }
            lock.unlock()
        }
    }
    
    private func checkShouldFinish() {
        if processingValueForChild == nil && upstreamSubscriptions.shouldFinish() {
            sendFinishDownstream()
            isFinished = true
        }
    }
    
    private func maybeDequeueValue() -> Downstream.Input? {
        return hasCompleteValueAvailable ? dequeueValue() : nil
    }
    
    private func sendSubscriptionDownstream() {
        downstream.receive(subscription: self)
    }
    
    // 如果, 所有的 Zip 节点中都有值了.
    // 这时候, 会在锁的环境下.
    private var hasCompleteValueAvailable: Bool {
        return upstreamSubscriptions.allSatisfy { $0.hasValue }
    }
    
    private var areMoreValuesPossible: Bool {
        // More values are possible if all children are (active || have surplus)
        return upstreamSubscriptions
            .allSatisfy { $0.state == .active || $0.hasValue }
    }
    
    // 给后方节点传值, 并且, 接收到后方节点发挥来的 demand 数据.
    @discardableResult
    private func processValue() -> Subscribers.Demand? {
        lock.lock()
        defer {
            valueIsBeingProcessed = false
            processingValueForChild = nil
            demandReceivedWhileProcessing = nil
            lock.unlock()
        }
        
        if let value = self.value {
            if downstreamDemand != .none {
                downstreamDemand -= 1
            }
            let newDemand = downstream.receive(value)
            if newDemand != .none {
                downstreamDemand += newDemand
                demandReceivedWhileProcessing = newDemand
            }
            self.value = nil
        }
        
        return demandReceivedWhileProcessing
    }
    
    private func sendRequestUpstream(demand: Subscribers.Demand) {
        lock.lock()
        let subscriptionsToRequest = upstreamSubscriptions
            .filter { $0.childIndex != processingValueForChild?.childIndex }
        lock.unlock()
        subscriptionsToRequest.forEach { $0.request(demand) }
    }
    
    private func sendFinishDownstream() {
        downstream.receive(completion: .finished)
        lock.lock()
        let activeChildren = upstreamSubscriptions.filter { $0.state == .active }
        lock.unlock()
        activeChildren.forEach { $0.cancel() }
    }
}

extension InnerBase: Subscription {
    fileprivate final func request(_ demand: Subscribers.Demand) {
        guard demand != .none else {
            fatalError()
        }
        lock.lock()
        downstreamDemand += demand
        // 当, Zip 节点, 收到 Demand 的请求之后, 将请求转发给所有的 zip 子节点.
        sendRequestUpstream(demand: demand)
        if valueIsBeingProcessed {
            demandReceivedWhileProcessing = demand
        } else {
            valueIsBeingProcessed = true
            processValue()
        }
        lock.unlock()
    }
    
    fileprivate final func cancel() {
        lock.lock()
        let subscriptionsToCancel = upstreamSubscriptions
        lock.unlock()
        subscriptionsToCancel.forEach { $0.cancel() }
    }
}

extension Array where Element == ChildSubscription {
    func shouldFinish() -> Bool {
        for subscription in self where subscription.state == .finished && !subscription.hasValue{
            return true
        }
        return false
    }
}

private enum ChildState {
    case waitingForSubscription
    case active
    case finished
    case failed
    case canceled
}

// Note that it's critical that this protocol not have any associated types - specifically
// note that it does not refer to `Upstream`.
// This allows `InnerBase` to do most of the heavy lifting without regard to the
// upstream publisher's value type.
private protocol ChildSubscription: AnyObject, Subscription {
    var state: ChildState { get set }
    var childIndex: Int { get }
    var hasValue: Bool { get }
}

fileprivate final class ChildSubscriber<Upstream: Publisher, Downstream: Subscriber>
where Upstream.Failure == Downstream.Failure
{
    typealias Input = Upstream.Output
    typealias Failure = Upstream.Failure
    
    fileprivate final var state: ChildState = .waitingForSubscription
    fileprivate final var upstreamSubscription: Subscription?
    private var values = [Upstream.Output]() // 每个上游发送过来的数据, 自己进行存储.
    fileprivate let childIndex: Int
    
    private unowned let parent: InnerBase<Downstream>
    
    init(_ parent: InnerBase<Downstream>, _ childIndex: Int) {
        self.parent = parent
        self.childIndex = childIndex
    }
    
    fileprivate final func dequeueValue() -> Upstream.Output {
        return values.remove(at: 0)
    }
}

extension ChildSubscriber: ChildSubscription {
    fileprivate final var hasValue: Bool {
        return !values.isEmpty
    }
}

extension ChildSubscriber: Subscription {
    fileprivate final func request(_ demand: Subscribers.Demand) {
        upstreamSubscription?.request(demand)
    }
}

extension ChildSubscriber: Cancellable {
    // 通知上游节点取消.
    fileprivate final func cancel() {
        upstreamSubscription?.cancel()
        upstreamSubscription = nil
    }
}

extension ChildSubscriber: Subscriber {
    fileprivate final func receive(subscription: Subscription) {
        if upstreamSubscription == nil {
            upstreamSubscription = subscription
            parent.receivedSubscription(for: self)
        } else {
            subscription.cancel()
        }
    }
    
    fileprivate final func receive(_ input: Input) -> Subscribers.Demand {
        return parent.receivedChildValue(child: self) { values.append(input) }
    }
    
    fileprivate final func receive(completion: Subscribers.Completion<Failure>) {
        parent.receivedCompletion(completion, forChild: self)
    }
}
