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
            /*
             Execute an operation with a cancellation handler that’s immediately invoked if the current task is canceled.
             使用立即调用的取消处理程序执行一个操作，如果当前任务被取消。
             This differs from the operation cooperatively checking for cancellation and reacting to it in that the cancellation handler is always and immediately invoked when the task is canceled.
             For example, even if the operation is running code that never checks for cancellation, a cancellation handler still runs and provides a chance to run some cleanup code.
             这与协作检查取消并对其做出反应的操作不同，因为取消处理程序在任务被取消时总是立即被调用。例如，即使操作正在运行从不检查取消的代码，取消处理程序仍会运行并提供机会运行一些清理代码。

             Cancellation handlers which acquire locks must take care to avoid deadlock.
             The cancellation handler may be invoked while holding internal locks associated with the task or other tasks.
             Other operations on the task, such as resuming a continuation, may acquire these same internal locks. Therefore, if a cancellation handler must acquire a lock, other code should not cancel tasks or resume continuations while holding that lock.
             取消处理程序必须小心避免死锁，如果它们获取锁。取消处理程序可能在持有与任务或其他任务相关的内部锁时被调用。对任务的其他操作，例如恢复继续，可能会获取相同的内部锁。因此，如果取消处理程序必须获取锁，则在持有该锁时，其他代码不应取消任务或恢复继续。

             Doesn’t check for cancellation, and always executes the passed operation.
             不检查取消，并始终执行传递的 operation 。

             The operation executes on the calling execution context and does not suspend by itself, unless the code contained within the closure does. If cancellation occurs while the operation is running, the cancellation handler will execute concurrently with the operation.
             operation 在调用执行上下文中执行，并且不会自行暂停，除非闭包中包含的代码暂停。如果在操作运行时发生取消，取消 handler 将与 operation 并发执行。

             Already cancelled tasks 已取消的任务
             When withTaskCancellationHandler is used in a Task that has already been cancelled, the onCancel cancellation handler will be executed immediately before operation gets to execute. This allows the cancellation handler to set some external “cancelled” flag that the operation may be atomically checking for in order to avoid performing any actual work once the operation gets to run.
             当 withTaskCancellationHandler 在已经被取消的 Task 中使用时， onCancel 取消 handler 将在操作执行之前立即执行。这允许取消处理程序设置一些外部的“取消”标志，操作可能会原子地检查以避免在操作运行时执行任何实际工作。
             
             withTaskCancellationHandler {
                 
             } onCancel: {
                 
             }
             
             withTaskCancellationHandler 是 Swift 5.5 中引入的一个新的 API，它允许你在任务被取消时执行一些清理工作。
             withTaskCancellationHandler 函数接受两个闭包参数：一个是你的主任务，另一个是在任务被取消时需要执行的清理工作。这个函数会返回主任务
             */
            // 当异步任务取消了之后, 直接将前置的 Publisher 也尽心了取消. 
            return await withTaskCancellationHandler(
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
