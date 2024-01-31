//
//  Publishers.Collect.swift
//  
//
//  Created by Sergej Jaskiewicz on 09.10.2019.
//

extension Publisher {

    /// Collects all received elements, and emits a single array of the collection when
    /// the upstream publisher finishes.
    ///
    /// Use `collect()` to gather elements into an array that the operator emits after
    /// the upstream publisher finishes.
    ///
    /// If the upstream publisher fails with an error, this publisher forwards the error
    /// to the downstream receiver instead of sending its output.
    ///
    /// This publisher requests an unlimited number of elements from the upstream
    /// publisher and uses an unbounded amount of memory to store the received values.
    /// The publisher may exert memory pressure on the system for very large sets of
    /// elements.
    ///
    /// The `collect()` operator only sends the collected array to its downstream receiver
    /// after a request whose demand is greater than 0 items. Otherwise, `collect()` waits
    /// until it receives a non-zero request.
    ///
    /// In the example below, an Integer range is a publisher that emits an array of
    /// integers:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .collect()
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// - Returns: A publisher that collects all received items and returns them as
    ///   an array upon completion.
    ///
    /// 收集所有接收到的元素，并在上游发布者完成时发出一次包含该集合的数组。
    ///
    /// 使用 `collect()` 将元素收集到一个数组中，该运算符在上游发布者完成后将该数组发出。
    ///
    /// 如果上游发布者以错误失败，此发布者将将错误转发给下游接收器，而不是发送其输出。
    ///
    /// 此发布者从上游发布者请求无限数量的元素，并使用无限的内存来存储接收到的值。
    /// 对于非常大的元素集，此发布者可能对系统施加内存压力。
    ///
    /// `collect()` 运算符仅在请求的需求数量大于 0 项时才将收集到的数组发送给下游接收器。否则，`collect()` 将等待直到收到非零请求。
    ///
    /// 在下面的示例中，一个整数范围是一个发布者，发出一个整数数组：
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .collect()
    ///         .sink { print("\($0)") }
    ///
    ///     // 输出: "[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]"
    ///
    /// - Returns: 一个发布者，它收集所有接收到的项目，并在完成时作为数组返回它们。

    public func collect() -> Publishers.Collect<Self> {
        return .init(upstream: self)
    }
}

extension Publishers {

    /// A publisher that buffers items.
    public struct Collect<Upstream: Publisher>: Publisher {

        public typealias Output = [Upstream.Output]

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Downstream.Input == [Upstream.Output]
        {
            upstream.subscribe(Inner(downstream: subscriber))
        }
    }
}

extension Publishers.Collect: Equatable where Upstream: Equatable {}

extension Publishers.Collect {
    private final class Inner<Downstream: Subscriber>
        : ReduceProducer<Downstream,
                         Upstream.Output,
                         [Upstream.Output],
                         Upstream.Failure,
                         Void>
        where Downstream.Input == [Upstream.Output],
              Downstream.Failure == Upstream.Failure
    {
        fileprivate init(downstream: Downstream) {
            // initial 是 [].
            // 一定要传递 reduce 的值.
            super.init(downstream: downstream, initial: [], reduce: ())
        }

        override func receive(
            newValue: Upstream.Output
        ) -> PartialCompletion<Void, Downstream.Failure> {
            result!.append(newValue)
            return .continue
        }

        override var description: String {
            return "Collect"
        }

        override var customMirror: Mirror {
            let children: CollectionOfOne<Mirror.Child> = .init(("count", result!.count))
            return Mirror(self, children: children)
        }
    }
}
