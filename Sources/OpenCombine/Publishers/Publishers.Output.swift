//
//  Publishers.Output.swift
//  
//
//  Created by Sergej Jaskiewicz on 24.10.2019.
//

extension Publisher {

    /// Republishes elements up to the specified maximum count.
    ///
    /// Use `prefix(_:)` to limit the number of elements republished to the downstream
    /// subscriber.
    ///
    /// In the example below, the `prefix(_:)` operator limits its output to the first
    /// two elements before finishing normally:
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .prefix(2)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1"
    ///
    /// - Parameter maxLength: The maximum number of elements to republish.
    /// - Returns: A publisher that publishes up to the specified number of elements
    ///   before completing.
    
    /// 重新发布元素，最多达到指定的最大计数。
    ///
    /// 使用 `prefix(_:)` 限制要重新发布到下游订阅者的元素数量。
    ///
    /// 在下面的示例中，`prefix(_:)` 操作符将输出限制为前两个元素，然后正常完成：
    ///
    ///     let numbers = (0...10)
    ///     cancellable = numbers.publisher
    ///         .prefix(2)
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "0 1"
    ///
    /// - Parameter maxLength: 要重新发布的元素的最大数量。
    /// - Returns: 一个发布者，在完成之前发布最多指定数量的元素。

    public func prefix(_ maxLength: Int) -> Publishers.Output<Self> {
        return output(in: ..<maxLength)
    }
}

extension Publisher {

    /// Publishes a specific element, indicated by its index in the sequence of published
    /// elements.
    ///
    /// Use `output(at:)` when you need to republish a specific element specified by
    /// its position in the stream. If the publisher completes normally or with an error
    /// before publishing the specified element, then the publisher doesn’t produce any
    /// elements.
    ///
    /// In the example below, the array publisher emits the fifth element in the sequence
    /// of published elements:
    ///
    ///     let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    ///     numbers.publisher
    ///         .output(at: 5)
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "6"
    ///
    /// - Parameter index: The index that indicates the element to publish.
    /// - Returns: A publisher that publishes a specific indexed element.
    
    /// 发布特定的元素，由其在已发布元素序列中的索引表示。
    ///
    /// 当需要重新发布由其在流中的位置指定的特定元素时，使用 `output(at:)`。如果发布者正常完成或在发布指定元素之前出现错误，则发布者不会产生任何元素。
    ///
    /// 在下面的示例中，数组发布者发出已发布元素序列中的第五个元素：
    ///
    ///     let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    ///     numbers.publisher
    ///         .output(at: 5)
    ///         .sink { print("\($0)") }
    ///
    ///     // Prints: "6"
    ///
    /// - Parameter index: 表示要发布的元素的索引。
    /// - Returns: 一个发布者，发布特定索引的元素。

    public func output(at index: Int) -> Publishers.Output<Self> {
        return output(in: index...index)
    }

    /// Publishes elements specified by their range in the sequence of published elements.
    ///
    /// Use `output(in:)` to republish a range indices you specify in the published
    /// stream. After publishing all elements, the publisher finishes normally.
    /// If the publisher completes normally or with an error before producing all
    /// the elements in the range, it doesn’t publish the remaining elements.
    ///
    /// In the example below, an array publisher emits the subset of elements at
    /// the indices in the specified range:
    ///
    ///     let numbers = [1, 1, 2, 2, 2, 3, 4, 5, 6]
    ///     numbers.publisher
    ///         .output(in: (3...5))
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "2 2 3"
    ///
    /// - Parameter range: A range that indicates which elements to publish.
    /// - Returns: A publisher that publishes elements specified by a range.
    
    /// 发布由其在已发布元素序列中的范围指定的元素。
    ///
    /// 使用 `output(in:)` 重新发布你在已发布流中指定的索引范围。在发布所有元素后，发布者将正常完成。
    /// 如果发布者在生成范围内的所有元素之前正常完成或出现错误，则不会发布剩余的元素。
    ///
    /// 在下面的示例中，数组发布者发出指定范围内索引的元素子集：
    ///
    ///     let numbers = [1, 1, 2, 2, 2, 3, 4, 5, 6]
    ///     numbers.publisher
    ///         .output(in: (3...5))
    ///         .sink { print("\($0)", terminator: " ") }
    ///
    ///     // Prints: "2 2 3"
    ///
    /// - Parameter range: 一个指示要发布的元素的范围。
    /// - Returns: 一个发布者，发布由范围指定的元素。

    public func output<Range: RangeExpression>(in range: Range) -> Publishers.Output<Self>
        where Range.Bound == Int
    {
        return .init(upstream: self, range: range.relative(to: 0 ..< .max))
    }
}

extension Publishers {

    /// A publisher that publishes elements specified by a range in the sequence of
    /// published elements.
    public struct Output<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream

        /// The range of elements to publish.
        public let range: CountableRange<Int>

        /// Creates a publisher that publishes elements specified by a range.
        ///
        /// - Parameters:
        ///   - upstream: The publisher that this publisher receives elements from.
        ///   - range: The range of elements to publish.
        public init(upstream: Upstream, range: CountableRange<Int>) {
            precondition(range.lowerBound >= 0, "lowerBound must not be negative")
            precondition(range.upperBound >= 0, "upperBound must not be negative")
            self.upstream = upstream
            self.range = range
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(downstream: subscriber, range: range))
        }
    }
}

extension Publishers.Output: Equatable where Upstream: Equatable {}

extension Publishers.Output {
    private final class Inner<Downstream: Subscriber>
        : Subscriber,
          Subscription,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        // NOTE: This class has been audited for thread safety

        typealias Input = Upstream.Output

        typealias Failure = Upstream.Failure

        private let downstream: Downstream

        private var status = SubscriptionStatus.awaitingSubscription

        private var remainingUntilStart: Int

        private var remainingCount: Int

        private let lock = UnfairLock.allocate()

        fileprivate init(downstream: Downstream, range: CountableRange<Int>) {
            self.downstream = downstream
            self.remainingUntilStart = range.lowerBound
            self.remainingCount = range.count
        }

        deinit {
            lock.deallocate()
        }

        // 惯例实现.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = status else {
                lock.unlock()
                subscription.cancel()
                return
            }
            status = .subscribed(subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            // 如果 remainingUntilStart 还没有到达, 不断地进行消耗.
            if remainingUntilStart > 0 {
                remainingUntilStart -= 1
                return .max(1)
            }

            // 不断地消耗 remainingCount 的值.
            let newDemand: Subscribers.Demand
            if remainingCount > 0 {
                remainingCount -= 1
                newDemand = downstream.receive(input)
            } else {
                newDemand = .none
                cancelUpstreamAndFinish()
            }
            return newDemand
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            lock.lock()
            guard case .subscribed = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }

        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            subscription.request(demand)
        }

        func cancel() {
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            subscription.cancel()
        }

        var description: String { return "Output" }

        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }

        var playgroundDescription: Any { return description }

        // MARK: - Private

        // Range 消耗完毕了, 就发送 Complte 的事件. 
        private func cancelUpstreamAndFinish() {
            assert(remainingCount == 0)
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            status = .terminal
            lock.unlock()
            subscription.cancel()
            downstream.receive(completion: .finished)
        }
    }
}
