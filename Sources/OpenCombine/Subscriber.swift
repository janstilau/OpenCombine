/// A protocol that declares a type that can receive input from a publisher.
///
/// A `Subscriber` instance receives a stream of elements from a `Publisher`, along with
/// life cycle events describing changes to their relationship. A given subscriber’s
/// `Input` and `Failure` associated types must match the `Output` and `Failure` of its
/// corresponding publisher.
///
/// You connect a subscriber to a publisher by calling the publisher’s `subscribe(_:)`
/// method.  After making this call, the publisher invokes the subscriber’s
/// `receive(subscription:)` method. This gives the subscriber a `Subscription` instance,
/// which it uses to demand elements from the publisher, and to optionally cancel
/// the subscription. After the subscriber makes an initial demand, the publisher calls
/// `receive(_:)`, possibly asynchronously, to deliver newly-published elements.
/// If the publisher stops publishing, it calls `receive(completion:)`, using a parameter
/// of type `Subscribers.Completion` to indicate whether publishing completes normally or
/// with an error.
///
/// OpenCombine provides the following subscribers as operators on the `Publisher` type:
///
/// - `sink(receiveCompletion:receiveValue:)` executes arbitrary closures when
///   it receives a completion signal and each time it receives a new element.
/// - `assign(to:on:)` writes each newly-received value to a property identified by
///   a key path on a given instance.

/// 一个声明能够从发布者接收输入的类型的协议。
///
/// Subscriber 实例从 Publisher 接收一系列元素，以及描述它们之间关系变化的生命周期事件。给定订阅者的 Input 和 Failure 相关联的类型必须与其对应的发布者的 Output 和 Failure 匹配。

/// 通过调用发布者的 subscribe(_:) 方法，您将订阅者连接到发布者。在进行此调用后，发布者调用订阅者的 receive(subscription:) 方法。这会给订阅者提供一个 Subscription 实例，用于从发布者那里请求元素，以及可选地取消订阅。在订阅者进行初始请求后，发布者调用 receive(_:)，可能是异步的，以传递新发布的元素。如果发布者停止发布，它会调用 receive(completion:)，使用类型为 Subscribers.Completion 的参数来指示发布是正常完成还是出现错误。
///
/// OpenCombine 在 Publisher 类型上提供以下订阅者作为操作符：
///
/// - sink(receiveCompletion:receiveValue:) 在接收到完成信号时执行任意闭包，并在每次接收到新元素时执行。
/// - assign(to:on:) 将每个新接收的值写入由给定实例上的键路径标识的属性
public protocol Subscriber: CustomCombineIdentifierConvertible {

    /// The kind of values this subscriber receives.
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
    func receive(subscription: Subscription)

    /// Tells the subscriber that the publisher has produced an element.
    ///
    /// - Parameter input: The published element.
    /// - Returns: A `Subscribers.Demand` instance indicating how many more elements
    ///   the subscriber expects to receive.
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
