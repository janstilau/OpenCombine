#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

// 将 Compbine 的 Publisher, 变为一个 AsyncSequence 的过程.
#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Publisher where Failure == Never {

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: AsyncPublisher<Self> {
        return .init(self)
    }
}

// 不会产生错误的情形.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AsyncPublisher<Upstream: Publisher>: AsyncSequence
    where Upstream.Failure == Never
{

    public typealias Element = Upstream.Output

    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        public mutating func next() async -> Element? {
            return
            /*
             这与协作地检查取消并对其做出反应的操作不同之处在于，当任务被取消时，取消处理程序总是会立即被调用。

             例如，即使操作正在运行从不检查取消的代码，取消处理程序仍然会运行并提供机会运行一些清理代码。

             获取锁的取消处理程序必须小心避免死锁。

             取消处理程序可能在持有与任务或其他任务关联的内部锁时被调用。

             对任务的其他操作，例如恢复一个继续操作，可能会获取这些相同的内部锁。

             因此，如果取消处理程序必须获取锁，则在持有该锁时其他代码不应取消任务或恢复继续操作，以避免死锁。

             不检查取消，并且始终执行传递的操作。

             操作在调用方的执行上下文中执行，并且除非闭包内的代码自己挂起，否则不会自行挂起。

             如果在操作运行时发生取消，取消处理程序将与操作并发执行。

             已经取消的任务。

             当在已经取消的任务中使用 withTaskCancellationHandler 时，onCancel 取消处理程序将在操作执行之前立即执行。

             这使得取消处理程序可以设置一些外部的“已取消”标志，供操作在执行前原子地检查，以避免执行任何实际工作。
             */
            await withTaskCancellationHandler(
                handler: { [inner] in inner.cancel() },
                operation: { [inner] in await inner.next() }
            )
        }
    }

    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

// 一定, 是需要一个对象, 作为上游的最终 Subscriber 的. 然后在 Subscriber 内部, 每接受到一个值, 触发一下协程控制.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncPublisher.Iterator {

    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal
        }

        private let lock = UnfairLock.allocate()
        private var pendedContinuation: [UnsafeContinuation<Input?, Never>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                let pendedContinuation = self.pendedContinuation.take()
                lock.unlock()
                pendedContinuation.resumeAllWithNil()
                return .none
            }
            precondition(!pendedContinuation.isEmpty, "Received an output without requesting demand")
            // 拿到值了, 显示地告诉下游.
            // 使用原来存储的续体, 进行对应环境的唤醒.
            let continuation = pendedContinuation.removeFirst()
            lock.unlock()
            continuation.resume(returning: input)
            return .none
        }

        // 结束了, 显示地告诉下游.
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            state = .terminal
            let pendedContinuation = self.pendedContinuation.take()
            lock.unlock()
            pendedContinuation.resumeAllWithNil()
        }

        func cancel() {
            lock.lock()
            // 结束了, 显示地告诉下游.
            let pendedContinuation = self.pendedContinuation.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal
                lock.unlock()
                pendedContinuation.resumeAllWithNil()
                return
            }
            state = .terminal
            lock.unlock()
            subscription.cancel()
            pendedContinuation.resumeAllWithNil()
        }

        // 这是外界进行触发的地方.
        fileprivate func next() async -> Input? {
            return await withUnsafeContinuation { continuation in
                // 所有的 lock, unlock, 都在 await 一侧完成的.
                // 这里是需要锁的, 因为协程的运行环境, 其实是未知的.
                lock.lock()
                switch state {
                case .awaitingSubscription:
                    // 还没开始, 存一下.
                    pendedContinuation.append(continuation)
                    pendingDemand += 1
                    lock.unlock()
                case .subscribed(let subscription):
                    // 已经开始了, 存一下, 然后向上游要一下.
                    pendedContinuation.append(continuation)
                    lock.unlock()
                    subscription.request(.max(1))
                case .terminal:
                    // 结束了, 直接告诉下游, nil.
                    lock.unlock()
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
extension Publisher {

    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: AsyncThrowingPublisher<Self> {
        return .init(self)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AsyncThrowingPublisher<Upstream: Publisher>: AsyncSequence
{

    public typealias Element = Upstream.Output

    public struct Iterator: AsyncIteratorProtocol {

        public typealias Element = Upstream.Output

        fileprivate let inner: Inner

        public mutating func next() async throws -> Element? {
            
            return try await withTaskCancellationHandler(
                handler: { [inner] in inner.cancel() },
                operation: { [inner] in try await inner.next() }
            )
        }
    }

    public typealias AsyncIterator = Iterator

    private let publisher: Upstream

    public init(_ publisher: Upstream) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> Iterator {
        let inner = Iterator.Inner()
        publisher.subscribe(inner)
        return Iterator(inner: inner)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension AsyncThrowingPublisher.Iterator {

    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal(Error?)
        }

        private let lock = UnfairLock.allocate()
        private var pendedContinuation: [UnsafeContinuation<Input?, Error>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none

        deinit {
            lock.deallocate()
        }

        func receive(subscription: Subscription) {
            lock.lock()
            guard case .awaitingSubscription = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            lock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }

        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case .subscribed = state else {
                let pendedContinuation = self.pendedContinuation.take()
                lock.unlock()
                pendedContinuation.resumeAllWithNil()
                return .none
            }
            precondition(!pendedContinuation.isEmpty, "Received an output without requesting demand")
            let continuation = pendedContinuation.removeFirst()
            lock.unlock()
            continuation.resume(returning: input)
            return .none
        }

        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            switch state {
            case .awaitingSubscription, .subscribed:
                if let continuation = pendedContinuation.first {
                    state = .terminal(nil)
                    let remaining = pendedContinuation.take().dropFirst()
                    lock.unlock()
                    switch completion {
                    case .finished:
                        continuation.resume(returning: nil)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    remaining.resumeAllWithNil()
                } else {
                    state = .terminal(completion.failure)
                    lock.unlock()
                }
            case .terminal:
                let pendedContinuation = self.pendedContinuation.take()
                lock.unlock()
                pendedContinuation.resumeAllWithNil()
            }
        }

        func cancel() {
            lock.lock()
            let pendedContinuation = self.pendedContinuation.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal(nil)
                lock.unlock()
                pendedContinuation.resumeAllWithNil()
                return
            }
            state = .terminal(nil)
            lock.unlock()
            subscription.cancel()
            pendedContinuation.resumeAllWithNil()
        }

        fileprivate func next() async throws -> Input? {
            return try await withUnsafeThrowingContinuation { continuation in
                lock.lock()
                switch state {
                case .awaitingSubscription:
                    pendedContinuation.append(continuation)
                    pendingDemand += 1
                    lock.unlock()
                case .subscribed(let subscription):
                    pendedContinuation.append(continuation)
                    lock.unlock()
                    subscription.request(.max(1))
                case .terminal(nil):
                    lock.unlock()
                    continuation.resume(returning: nil)
                case .terminal(let error?):
                    state = .terminal(nil)
                    lock.unlock()
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Sequence {
    fileprivate func resumeAllWithNil<Output, Failure: Error>()
        where Element == UnsafeContinuation<Output?, Failure>
    {
        for continuation in self {
            continuation.resume(returning: nil)
        }
    }
}
#endif
