
/// Declares that a type can transmit a sequence of values over time.
/// A publisher delivers elements to one or more `Subscriber` instances.

/// 泛型类型约束. 做类型绑定用.
/// The subscriber’s `Input` and `Failure` associated types must match the `Output` and
/// `Failure` types declared by the publisher.
/// The publisher implements the `receive(subscriber:)`method to accept a subscriber. Attach.

/// After this, the publisher can call the following methods on the subscriber:
// Publisher 首先按照自己的业务特点生成一个 Subscription 对象, 然后一定要主动调用这个方法, 只有这样, 才可以让 Subscriber 循环引用到 subscription
/// - `receive(subscription:)`: Acknowledges the subscribe request and returns
///   a `Subscription` instance. The subscriber uses the subscription to demand elements
///   from the publisher and can use it to cancel publishing.

// 同样的, Subscriber 在实现 receive(subscription 要做一些固定的事情.
// 1. 强引用, 来作为循环引用, 保证响应者链条存在.
// 2. 调用 request demand 方法, 来让上方节点, 进行被压管理. 和 Rx 的 Push 模型不同, Combine 里面, 是 Pull 模型, 由下方节点, 来进行数据的 Demand 管理. 其实, Combine 还是 Push 的机制, 只不过在 Comibine 里面, 进行了 Pull 的尊重. 触发的实际, 还是上游节点决定的. 但是, 如果下游节点不需要, 上游节点不应该把相应的数据传递过来.


// Publisher 生成的 Subscription 里面, 主动调用 Subscriber 的 Receive 方法, 将自己生成出来的数据, 主动交给下游节点.
/// - `receive(_:)`: Delivers one element from the publisher to the subscriber.

// Publisher 生成 Subscription 里面, 主动调用 Subscribe 的 receive(completion 方法, 将结束事件交给下游节点.
/// - `receive(completion:)`: Informs the subscriber that publishing has ended,
///   either normally or with an error.
// 可以看到, 实际上, 按照自己的业务, 进行处理的对象, 其实是各个 Publisher 的 Subscription 对象. 和后续的 Subscribe 的交互, 也都是这个 Subscription 对象在起作用.


/// Every `Publisher` must adhere to this contract for downstream subscribers to function
/// correctly.
// Publihser 是泛型绑定的, 同样的, 他生成的 Subscription 也是泛型绑定的. 而这个 Subscription, 其实是和下游的 Subscriber 类型要相符的.
// 所以, Publisher 和 它的下游 Publisher 的类型相符, 真正起到作用的地方, 是两个 Publisher 所生成的节点, 类型要匹配上. 不过这都是实现细节.

/// Extensions on `Publisher` define a wide variety of operators that you compose to
/// create sophisticated event-processing chains.

// 各个 Producer, 记录的是上游节点的 Producer. 所以, 在没有真正的 subcribe 之前, 是各个 Producer 的串联. 这个串联, 可以就是理解为缓存异步逻辑, 这些异步逻辑, 在真正生成响应链条的时候, 会复制过去.
// Subscribe 的过程, 其实就是根据上方的 Producer 链条, 生成 Node 节点的过程. 从后向前.
// 在这个过程中, 各个节点生成各自的 Subscription 对象, 作为响应链条的真正节点对象.
/// Each operator returns a type that implements the `Publisher` protocol
/// Most of these types exist as extensions on the `Publishers` enumeration.
/// For example, the `map(_:)` operator returns an instance of `Publishers.Map`.


/// # Creating Your Own Publishers
/// Rather than implementing the `Publisher` protocol yourself, you can create your own
/// publisher by using one of several types provided by the OpenCombine framework:
///
/// - Use a concrete subclass of `Subject`, such as `PassthroughSubject`, to publish
///   values on-demand by calling its `send(_:)` method.
/// - Use a `CurrentValueSubject` to publish whenever you update the subject’s underlying
///   value.
/// Rx 里面, 基本就是 Subject 作为成员变量. 在 Combine 里面, 利用了 PropertyWrapper 技术.
/// - Add the `@Published` annotation to a property of one of your own types. In doing so,
///   the property gains a publisher that emits an event whenever the property’s value
///   changes. See the `Published` type for an example of this approach.

// 可以看到, 和 Rx 里面, 大量使用 Create 这个函数相比, Combine 其实更加的希望, 使用 Subject 这种技术来进行信号的触发.
// 猜测, 因为 Combine 其实是 Pull 驱动的, Create 这种方式, 没有办法做好管理. 而 Subject 的设计里面, 本身就有对于 Demand 的管理.
// 使用 Subject 作为响应式的起始节点, 也符合单一化原则.

public protocol Publisher {
    
    /// The kind of values published by this publisher.
    associatedtype Output
    
    /// The kind of errors this publisher might publish.
    /// Use `Never` if this `Publisher` does not publish errors.
    associatedtype Failure: Error
    
    // Attach, 官方也经常使用这个词.
    /// Attaches the specified subscriber to this publisher.
    ///
    /// Always call this function instead of `receive(subscriber:)`.
    /// Adopters of `Publisher` must implement `receive(subscriber:)`. The implementation
    /// of `subscribe(_:)` provided by `Publisher` calls through to
    /// `receive(subscriber:)`.
    ///
    /// - Parameter subscriber: The subscriber to attach to this publisher. After
    ///   attaching, the subscriber can start to receive values.
    
    // 这个函数, 有着固定的行为模式.
    // upstream.subscribe(Inner(downstream: subscriber, encode: _encode))
    // 自己内部, 生成一个 Subscription 节点.
    // 将, 传递过来的 subscriber, 当做 Subscription 的 DownStream 传入.
    // 然后, 将生成的 Subscription, 当做是 Subscriber, 调用 Producer 存储的 upstream 的 subscribe, 构建出完备的响应者链条.
    func receive<Subscriber: OpenCombine.Subscriber>(subscriber: Subscriber)
    where Failure == Subscriber.Failure, Output == Subscriber.Input
}

extension Publisher {
    
    /// Attaches the specified subscriber to this publisher.
    
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
    // 在 Combine 里面, Subejct 不自动是 Subscriber.
    // 当注册到 Subject 的时候, 其实可以认为是, 响应链条终止了. 后面的通路, 应该是已 Subject 为起点的, 新的响应链条.
    // 所以, 这里返回一个 cancellable, 来做这条通路的 cancel 的触发点.
    public func subscribe<Subject: OpenCombine.Subject>(
        _ subject: Subject
    ) -> AnyCancellable
    where Failure == Subject.Failure, Output == Subject.Output
    {
        let subscriber = SubjectSubscriber(subject)
        self.subscribe(subscriber)
        return AnyCancellable(subscriber)
    }
}
