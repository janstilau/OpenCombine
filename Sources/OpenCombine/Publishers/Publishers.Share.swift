//
//  Publishers.Share
//  
//
//  Created by Sergej Jaskiewicz on 18/09/2019.
//

extension Publisher {

    /// Shares the output of an upstream publisher with multiple subscribers.
    ///
    /// The publisher returned by this operator supports multiple subscribers, all of whom
    /// receive unchanged elements and completion states from the upstream publisher.
    ///
    ///  - Tip: `Publishers.Share` is effectively a combination of
    ///  the `Publishers.Multicast` and `PassthroughSubject` publishers, with an implicit
    ///  `autoconnect()`.
    ///
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator. It uses a `share()` operator
    /// to share the same random number to each of two subscribers. This example uses
    /// a `delay(for:tolerance:scheduler:options:)` operator only to prevent the first
    /// subscriber from exhausting the sequence publisher immediately; an asynchronous
    /// publisher wouldn’t need this.
    ///
    ///     let pub = (1...3).publisher
    ///         .delay(for: 1, scheduler: DispatchQueue.main)
    ///         .map( { _ in return Int.random(in: 0...100) } )
    ///         .print("Random")
    ///         .share()
    ///
    ///     cancellable1 = pub
    ///         .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///         .sink { print ("Stream 2 received: \($0)")}
    ///
    ///     // Prints:
    ///     // Random: receive value: (20)
    ///     // Stream 1 received: 20
    ///     // Stream 2 received: 20
    ///     // Random: receive value: (85)
    ///     // Stream 1 received: 85
    ///     // Stream 2 received: 85
    ///     // Random: receive value: (98)
    ///     // Stream 1 received: 98
    ///     // Stream 2 received: 98
    ///
    /// Without the `share()` operator, stream 1 receives three random values,
    /// followed by stream 2 receiving three different random values.
    ///
    /// Also note that `Publishers.Share` is a `class` rather than a `struct` like most
    /// other publishers. This means you can use this operator to create a publisher
    /// instance that uses reference semantics.
    ///
    /// - Returns: A class instance that shares elements received from its upstream to
    ///   multiple subscribers.
    
    /// 将上游发布者的输出共享给多个订阅者。
    ///
    /// 由此操作符返回的发布者支持多个订阅者，它们都从上游发布者接收不变的元素和完成状态。
    ///
    /// - 提示: `Publishers.Share` 实际上是 `Publishers.Multicast` 和 `PassthroughSubject` 发布者的组合，具有隐式的 `autoconnect()`。
    ///
    /// 以下示例使用序列发布者作为计数器，发布三个由 `map(_:)` 操作符生成的随机数。它使用 `share()` 操作符将相同的随机数传递给两个订阅者。
    /// 此示例仅使用 `delay(for:tolerance:scheduler:options:)` 操作符防止第一个订阅者立即耗尽序列发布者；异步发布者不需要这个。
    ///
    ///     let pub = (1...3).publisher
    ///         .delay(for: 1, scheduler: DispatchQueue.main)
    ///         .map( { _ in return Int.random(in: 0...100) } )
    ///         .print("Random")
    ///         .share()
    ///
    ///     cancellable1 = pub
    ///         .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///         .sink { print ("Stream 2 received: \($0)")}
    ///
    ///     // 输出:
    ///     // Random: receive value: (20)
    ///     // Stream 1 received: 20
    ///     // Stream 2 received: 20
    ///     // Random: receive value: (85)
    ///     // Stream 1 received: 85
    ///     // Stream 2 received: 85
    ///     // Random: receive value: (98)
    ///     // Stream 1 received: 98
    ///     // Stream 2 received: 98
    ///
    /// 没有 `share()` 操作符，Stream 1 接收三个随机值，然后 Stream 2 接收三个不同的随机值。
    ///
    /// 还请注意，`Publishers.Share` 是一个 `class`，而不是像大多数其他发布者一样是 `struct`。这意味着您可以使用此操作符创建使用引用语义的发布者实例。
    ///
    /// - Returns: 一个类实例，将其上游接收的元素共享给多个订阅者。

    public func share() -> Publishers.Share<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that shares the output of an upstream publisher with multiple
    /// subscribers.
    ///
    /// This publisher type supports multiple subscribers, all of whom receive unchanged
    /// elements and completion states from the upstream publisher.
    ///
    ///  - Tip: `Publishers.Share` is effectively a combination of
    ///  the `Publishers.Multicast` and `PassthroughSubject` publishers,
    ///  with an implicit `autoconnect()`.
    ///
    /// Also note that `Publishers.Share` is a `class` rather than a `struct` like most
    /// other publishers. Use this type when you need a publisher instance that uses
    /// reference semantics.
    public final class Share<Upstream: Publisher>: Publisher, Equatable {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        private typealias MulticastSubject = PassthroughSubject<Output, Failure>

        private let inner: Autoconnect<Multicast<Upstream, MulticastSubject>>

        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.inner = upstream.multicast(subject: .init()).autoconnect()
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Input == Output, Downstream.Failure == Failure
        {
            inner.subscribe(subscriber)
        }

        public static func == (lhs: Share, rhs: Share) -> Bool {
            return lhs === rhs
        }
    }
}
