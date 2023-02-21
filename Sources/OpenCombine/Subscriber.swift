/// A protocol that declares a type that can receive input from a publisher.

/// A `Subscriber` instance receives a stream of elements from a `Publisher`, along with
/// life cycle events describing changes to their relationship. A given subscriber’s
/// `Input` and `Failure` associated types must match the `Output` and `Failure` of its
/// corresponding publisher.

/// You connect a subscriber to a publisher by calling the publisher’s `subscribe(_:)`
/// method.
// 这里说的很清楚, Publihser 有责任, 去调用 Receiver 的 receive(subscription:) 方法.
// Publihser 内部, 生成了 Subscription 节点, 然后, 主动调用 receiver 的 receive(subscription:), 将生成的上游节点, 传递给 Subscriber 对象.
// 在 Subscriber 对象内, 一般会存储 Subscription 对象, 目的是为了, cancel 链条触发的时候, 可以触发上游节点的 cancel 事件. 同时, 这也是一个循环引用的达成. 使得节点可以单独存在.

/// After making this call, the publisher invokes the subscriber’s
/// `receive(subscription:)` method. This gives the subscriber a `Subscription` instance,
/// which it uses to demand elements from the publisher, and to optionally cancel
/// the subscription.
/// 
// 有着固定的行为流程, 这在实现 Publisher 的时候, 一定要遵守.
// 从目前的实现来看, 也会有这循环引用这件事的进行.

// 上游的节点, 主动调用下游节点的 receive value, 来进行数据的传输.
// Demand 这件事, 可以完成流量控制.
// 可以是上游必须由下游明确的进行 demand 的时候, 才进行生成. 这就是一个生产者消费者模型.
// 也可以是, 上游不断的生产, 但是下游没有 demand 的时候, 就认为下游没有消费的能力, 就不进行数据的传送.
/// After the subscriber makes an initial demand, the publisher calls
/// `receive(_:)`, possibly asynchronously, to deliver newly-published elements.
/// If the publisher stops publishing, it calls `receive(completion:)`, using a parameter
/// of type `Subscribers.Completion` to indicate whether publishing completes normally or
/// with an error.

/// OpenCombine provides the following subscribers as operators on the `Publisher` type:

/// - `sink(receiveCompletion:receiveValue:)` executes arbitrary closures when
///   it receives a completion signal and each time it receives a new element.
/// - `assign(to:on:)` writes each newly-received value to a property identified by
///   a key path on a given instance.

/*
 Subscriber 的三个方法, 具有明显的时间顺序.
 */
public protocol Subscriber: CustomCombineIdentifierConvertible {
    
    /// The kind of values this subscriber receives.
    // 泛型限制, 要和 Publisher 的 Output 完全对接.
    associatedtype Input
    
    /// The kind of errors this subscriber might receive.
    ///
    /// Use `Never` if this `Subscriber` cannot receive errors.
    associatedtype Failure: Error
    
    /// Tells the subscriber that it has successfully subscribed to the publisher and may
    /// request items.
    ///
    /// Use the received `Subscription` to request items from the publisher.
    /// - Parameter subscription: A subscription that represents the connection between
    ///   publisher and subscriber.
    // 其实, 就是 Publisher 生成 Inner Sink 对象.
    // 也就是, 整个响应链路的节点对象.
    func receive(subscription: Subscription)
    
    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    ///   the subscriber expects to receive.
    /*
     这可能是一个比较长的过程. 不是递归, 而是需要进行从源头到结尾 Subscriber, 因为需要返回值.
     然后结尾将自己的 demand 回传, 最终到源头.
     chain 在建立之后, 所有的数据发送, 都是在 chain 上进行完整路由的. 
     */
    func receive(_ input: Input) -> Subscribers.Demand
    
    /// Tells the subscriber that the publisher has completed publishing, either normally
    /// or with an error.
    ///
    /// - Parameter completion: A `Subscribers.Completion` case indicating whether
    ///   publishing completed normally or with an error.
    func receive(completion: Subscribers.Completion<Failure>)
}

extension Subscriber where Input == Void {
    /// Tells the subscriber that a publisher of void elements is ready to receive further
    /// requests.
    ///
    /// Use `Void` inputs and outputs when you want to signal that an event has occurred,
    /// but don’t need to send the event itself.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    /// the subscriber expects to receive.
    public func receive() -> Subscribers.Demand {
        return receive(())
    }
}
