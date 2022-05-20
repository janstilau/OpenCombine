
// 不太明白, 意义在哪里, 本身 Publisher 就是 subscribe 的时候, 才会触发真正的信号的生成.
// 延时生成 Publisher.
/// A publisher that awaits subscription before running the supplied closure
/// to create a publisher for the new subscriber.
public struct Deferred<DeferredPublisher: Publisher>: Publisher {
    
    /// The kind of values published by this publisher.
    public typealias Output = DeferredPublisher.Output
    
    /// The kind of errors this publisher might publish.
    ///
    /// Use `Never` if this `Publisher` does not publish errors.
    public typealias Failure = DeferredPublisher.Failure
    
    /// The closure to execute when this deferred publisher receives a subscription.
    /// The publisher returned by this closure immediately
    /// Receives the incoming subscription.
    // 真正的, 生成 Publisher 的闭包, 这要在创建的时候, 进行存储.
    // 这是这个类型, 最最重要的属性了.
    public let createPublisher: () -> DeferredPublisher
    
    /// Creates a deferred publisher.
    ///
    /// - Parameter createPublisher: The closure to execute
    /// when calling `subscribe(_:)`.
    public init(createPublisher: @escaping () -> DeferredPublisher) {
        self.createPublisher = createPublisher
    }
    
    /*
     Publisher 的惯例是, 生成该 Publisher 相关的节点对象, 节点对象和 downstream 节点相连, 然后将新生成的节点对象, attach 到上级 Publisher 上.
     但是 Deferred 的作用, 就是生成 Publisher. 所以 Deffer 一定是头节点.
     所以, 它的 receive<Downstream: Subscriber>(subscriber 就是, 生成头节点的 Publisher, 然后接受 Downstream 节点.
     */
    /// This function is called to attach the specified `Subscriber`
    /// to this `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Failure == Downstream.Failure,
          Output == Downstream.Input
    {
        let deferredPublisher = createPublisher()
        deferredPublisher.subscribe(subscriber)
    }
}
