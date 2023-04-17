/*
 这个操作符的作用是, 延缓头节点的生成动作. 一般来说, 用 Future 举例, 它是创建就进行了信号的生成, 如果没有后续操作, 那么这个信号生成就无意义了.
 使用 Defer, 生成动作存储, 直到真正的应该需要触发业务的时候, 才调用.
 */

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
    public let publisherCreator: () -> DeferredPublisher
    
    /// Creates a deferred publisher.
    ///
    /// - Parameter createPublisher: The closure to execute
    /// when calling `subscribe(_:)`.
    public init(createPublisher: @escaping () -> DeferredPublisher) {
        self.publisherCreator = createPublisher
    }
    
    /*
     Publisher 的惯例是, 生成该 Publisher 相关的节点对象, 节点对象和 downstream 节点相连, 然后将新生成的节点对象, attach 到上级 Publisher 上.
     但是 Deferred 的作用, 就是生成 Publisher. 所以 Deffer 一定是头节点.
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
        let deferredPublisher = publisherCreator()
        deferredPublisher.subscribe(subscriber)
    }
}
