/// Declares that a type can transmit a sequence of values over time.
///
/// A publisher delivers elements to one or more `Subscriber` instances.
/// The subscriber’s `Input` and `Failure` associated types must match the `Output` and
/// `Failure` types declared by the publisher.
/// The publisher implements the `receive(subscriber:)`method to accept a subscriber.
///
/// After this, the publisher can call the following methods on the subscriber:
/// - `receive(subscription:)`: Acknowledges the subscribe request and returns
///   a `Subscription` instance. The subscriber uses the subscription to demand elements
///   from the publisher and can use it to cancel publishing.
/// - `receive(_:)`: Delivers one element from the publisher to the subscriber.
/// - `receive(completion:)`: Informs the subscriber that publishing has ended,
///   either normally or with an error.
///
/// Every `Publisher` must adhere to this contract for downstream subscribers to function
/// correctly.
///
/// Extensions on `Publisher` define a wide variety of _operators_ that you compose to
/// create sophisticated event-processing chains.
/// Each operator returns a type that implements the `Publisher` protocol
/// Most of these types exist as extensions on the `Publishers` enumeration.
/// For example, the `map(_:)` operator returns an instance of `Publishers.Map`.
///
/// # Creating Your Own Publishers
///
/// Rather than implementing the `Publisher` protocol yourself, you can create your own
/// publisher by using one of several types provided by the OpenCombine framework:
///
/// - Use a concrete subclass of `Subject`, such as `PassthroughSubject`, to publish
///   values on-demand by calling its `send(_:)` method.
/// - Use a `CurrentValueSubject` to publish whenever you update the subject’s underlying
///   value.
/// - Add the `@Published` annotation to a property of one of your own types. In doing so,
///   the property gains a publisher that emits an event whenever the property’s value
///   changes. See the `Published` type for an example of this approach.

/// 声明一个类型可以随时间传输一系列值。
///
/// 一个发布者将元素传递给一个或多个Subscriber实例。
/// 订阅者的Input和Failure相关联的类型必须与发布者声明的Output和Failure类型相匹配。
/// 发布者实现receive(subscriber:)方法来接受订阅者。
///
/// 在此之后，发布者可以在订阅者上调用以下方法：
/// - receive(subscription:)：确认订阅请求并返回一个Subscription实例。订阅者使用订阅来要求元素
/// 从发布者获取，并可用于取消发布。
/// - receive(_:)：将一个元素从发布者传递给订阅者。
/// - receive(completion:)：通知订阅者发布已经结束，
/// 无论是正常结束还是出现错误。
///
/// 每个Publisher必须遵循此合同，以使下游订阅者正常运行。
///
/// 在Publisher上的扩展定义了各种各样的 操作符，您可以组合这些操作符来
/// 创建复杂的事件处理链。
/// 每个操作符都返回一个实现Publisher协议的类型
/// 这些类型大多数存在于Publishers枚举的扩展中。
/// 例如，map(_:)操作符返回Publishers.Map的实例。
///
/// # 创建您自己的发布者
///
/// 与其自己实现Publisher协议，不如使用OpenCombine框架提供的几种类型创建您自己
/// 发布者：
///
/// - 使用Subject的具体子类，例如PassthroughSubject，按需发布
/// 通过调用其send(_:)方法的值。
/// - 使用CurrentValueSubject在更新主题的基础值时发布。
/// - 向您自己类型的属性添加@Published注释。这样一来，
/// 属性获得了一个发布者，每当属性的值发生变化时就会发出事件。参见Published类型的示例。

public protocol Publisher {

    /// The kind of values published by this publisher.
    associatedtype Output

    /// The kind of errors this publisher might publish.
    ///
    /// Use `Never` if this `Publisher` does not publish errors.
    associatedtype Failure: Error

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Always call this function instead of `receive(subscriber:)`.
    /// Adopters of `Publisher` must implement `receive(subscriber:)`. The implementation
    /// of `subscribe(_:)` provided by `Publisher` calls through to
    /// `receive(subscriber:)`.
    ///
    /// - Parameter subscriber: The subscriber to attach to this publisher. After
    ///   attaching, the subscriber can start to receive values.
    func receive<Subscriber: OpenCombine.Subscriber>(subscriber: Subscriber)
        where Failure == Subscriber.Failure, Output == Subscriber.Input
}

extension Publisher {

    /// Attaches the specified subscriber to this publisher.
    ///
    /// Always call this function instead of `receive(subscriber:)`.
    /// Adopters of `Publisher` must implement `receive(subscriber:)`.
    /// The implementation of `subscribe(_:)` in this extension calls through to
    /// `receive(subscriber:)`.
    /// - SeeAlso: `receive(subscriber:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`. After attaching,
    ///       the subscriber can start to receive values.
    public func subscribe<Subscriber: OpenCombine.Subscriber>(_ subscriber: Subscriber)
        where Failure == Subscriber.Failure, Output == Subscriber.Input
    {
        if let hook = DebugHook.getGlobalHook() {
            if var marker = subscriber as? SubscriberTapMarker {
                let anySubscriber = marker.inner
                    as! AnySubscriber<Subscriber.Input, Subscriber.Failure>
                hook.willReceive(publisher: self, subscriber: anySubscriber)
                receive(subscriber: subscriber)
                hook.didReceive(publisher: self, subscriber: anySubscriber)
            } else {
                let tap = SubscriberTap(subscriber: subscriber)
                hook.willReceive(publisher: self, subscriber: subscriber)
                receive(subscriber: tap)
                hook.didReceive(publisher: self, subscriber: subscriber)
            }
        } else {
            receive(subscriber: subscriber)
        }
    }

    /// Attaches the specified subject to this publisher.
    ///
    /// - Parameter subject: The subject to attach to this publisher.
    public func subscribe<Subject: OpenCombine.Subject>(
        _ subject: Subject
    ) -> AnyCancellable
        where Failure == Subject.Failure, Output == Subject.Output
    {
        // Subject 是一个 Publisher, 它并不是一个 Receiver.
        // 所以需要 SubjectSubscriber 包装一下.
        // 这算是 Publisher 链条的中间节点. 后续的链条, 是链接到了 Subejct 上了.
        // 而这是将 Subject, 连接到前面的链条. 
        let subscriber = SubjectSubscriber(subject)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
