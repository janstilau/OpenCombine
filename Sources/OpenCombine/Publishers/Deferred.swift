/*
 对于有些 Publihser 来说, 生成 Publisher 的过程, 就会触发信号产生的逻辑.
 例如 Future, 对于这样的 Publisher 来说, Deferred 其实就有意义了.
 只有真正的进行 Sink 的时候, 才触发生成 Publisher 的逻辑, 在 sink 之前, 还可以使用 Publisher 进行 opertor 操作.
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
