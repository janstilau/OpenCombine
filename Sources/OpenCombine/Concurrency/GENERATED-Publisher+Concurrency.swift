// ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
// ┃                                                                                     ┃
// ┃                   Auto-generated from GYB template. DO NOT EDIT!                    ┃
// ┃                                                                                     ┃
// ┃                                                                                     ┃
// ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
//
//  Publisher+Concurrency.swift
// 
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Publisher where Failure == Never {
    
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var values: AsyncPublisher<Self> {
        return .init(self)
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct AsyncPublisher<Upstream: Publisher>: AsyncSequence
where Upstream.Failure == Never
{
    
    public typealias Element = Upstream.Output
    
    public struct Iterator: AsyncIteratorProtocol {
        
        public typealias Element = Upstream.Output
        
        fileprivate let inner: Inner
        
        public mutating func next() async -> Element? {
            return await withTaskCancellationHandler(
                operation: { [inner] in await inner.next() },
                onCancel: { [inner] in inner.cancel() }
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
extension AsyncPublisher.Iterator {
    
    fileprivate final class Inner: Subscriber, Cancellable {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure
        
        private enum State {
            case awaitingSubscription
            case subscribed(Subscription)
            case terminal
        }
        
        private let innerLock = UnfairLock.allocate()
        private var pending: [UnsafeContinuation<Input?, Never>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none
        
        deinit {
            innerLock.deallocate()
        }
        
        func receive(subscription: Subscription) {
            innerLock.lock()
            guard case .awaitingSubscription = state else {
                innerLock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            innerLock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            innerLock.lock()
            guard case .subscribed = state else {
                let pending = self.pending.take()
                innerLock.unlock()
                pending.resumeAllWithNil()
                return .none
            }
            precondition(!pending.isEmpty, "Received an output without requesting demand")
            let continuation = pending.removeFirst()
            innerLock.unlock()
            continuation.resume(returning: input)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            innerLock.lock()
            state = .terminal
            let pending = self.pending.take()
            innerLock.unlock()
            pending.resumeAllWithNil()
        }
        
        func cancel() {
            innerLock.lock()
            let pending = self.pending.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal
                innerLock.unlock()
                pending.resumeAllWithNil()
                return
            }
            state = .terminal
            innerLock.unlock()
            subscription.cancel()
            pending.resumeAllWithNil()
        }
        
        fileprivate func next() async -> Input? {
            return await withUnsafeContinuation { continuation in
                innerLock.lock()
                switch state {
                case .awaitingSubscription:
                    pending.append(continuation)
                    pendingDemand += 1
                    innerLock.unlock()
                case .subscribed(let subscription):
                    pending.append(continuation)
                    innerLock.unlock()
                    subscription.request(.max(1))
                case .terminal:
                    innerLock.unlock()
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
                operation: { [inner] in try await inner.next() },
                onCancel: { [inner] in inner.cancel() }
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
        
        private let innerLock = UnfairLock.allocate()
        private var pending: [UnsafeContinuation<Input?, Error>] = []
        private var state = State.awaitingSubscription
        private var pendingDemand = Subscribers.Demand.none
        
        deinit {
            innerLock.deallocate()
        }
        
        func receive(subscription: Subscription) {
            innerLock.lock()
            guard case .awaitingSubscription = state else {
                innerLock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(subscription)
            let pendingDemand = self.pendingDemand
            self.pendingDemand = .none
            innerLock.unlock()
            if pendingDemand != .none {
                subscription.request(pendingDemand)
            }
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            innerLock.lock()
            guard case .subscribed = state else {
                let pending = self.pending.take()
                innerLock.unlock()
                pending.resumeAllWithNil()
                return .none
            }
            precondition(!pending.isEmpty, "Received an output without requesting demand")
            let continuation = pending.removeFirst()
            innerLock.unlock()
            continuation.resume(returning: input)
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            innerLock.lock()
            switch state {
            case .awaitingSubscription, .subscribed:
                if let continuation = pending.first {
                    state = .terminal(nil)
                    let remaining = pending.take().dropFirst()
                    innerLock.unlock()
                    switch completion {
                    case .finished:
                        continuation.resume(returning: nil)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                    remaining.resumeAllWithNil()
                } else {
                    state = .terminal(completion.failure)
                    innerLock.unlock()
                }
            case .terminal:
                let pending = self.pending.take()
                innerLock.unlock()
                pending.resumeAllWithNil()
            }
        }
        
        func cancel() {
            innerLock.lock()
            let pending = self.pending.take()
            guard case .subscribed(let subscription) = state else {
                state = .terminal(nil)
                innerLock.unlock()
                pending.resumeAllWithNil()
                return
            }
            state = .terminal(nil)
            innerLock.unlock()
            subscription.cancel()
            pending.resumeAllWithNil()
        }
        
        fileprivate func next() async throws -> Input? {
            return try await withUnsafeThrowingContinuation { continuation in
                innerLock.lock()
                switch state {
                case .awaitingSubscription:
                    pending.append(continuation)
                    pendingDemand += 1
                    innerLock.unlock()
                case .subscribed(let subscription):
                    pending.append(continuation)
                    innerLock.unlock()
                    subscription.request(.max(1))
                case .terminal(nil):
                    innerLock.unlock()
                    continuation.resume(returning: nil)
                case .terminal(let error?):
                    state = .terminal(nil)
                    innerLock.unlock()
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
