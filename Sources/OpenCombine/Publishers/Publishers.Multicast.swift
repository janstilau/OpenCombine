//
//  Publishers.Multicast.swift
//  
//
//  Created by Sergej Jaskiewicz on 14.06.2019.
//

extension Publisher {
    
    /// Applies a closure to create a subject that delivers elements to subscribers.
    ///
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    /// This is useful when upstream publishers are doing expensive work you don’t want
    /// to duplicate, like performing network requests.
    ///
    /// In contrast with `multicast(subject:)`, this method produces a publisher that
    /// creates a separate `Subject` for each subscriber.
    ///
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator.
    /// It uses a `multicast(_:)` operator whose closure creates a `PassthroughSubject`
    /// to share the same random number to each of two subscribers. Because the multicast
    /// publisher is a `ConnectablePublisher`, publishing only begins after a call to
    /// `connect()`.
    ///
    ///     let pub = ["First", "Second", "Third"].publisher
    ///         .map( { return ($0, Int.random(in: 0...100)) } )
    ///         .print("Random")
    ///         .multicast { PassthroughSubject<(String, Int), Never>() }
    ///
    ///     cancellable1 = pub
    ///        .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///        .sink { print ("Stream 2 received: \($0)")}
    ///     pub.connect()
    ///
    ///     // Prints:
    ///     // Random: receive value: (("First", 9))
    ///     // Stream 2 received: ("First", 9)
    ///     // Stream 1 received: ("First", 9)
    ///     // Random: receive value: (("Second", 46))
    ///     // Stream 2 received: ("Second", 46)
    ///     // Stream 1 received: ("Second", 46)
    ///     // Random: receive value: (("Third", 26))
    ///     // Stream 2 received: ("Third", 26)
    ///     // Stream 1 received: ("Third", 26)
    ///
    /// In this example, the output shows that the `print(_:to:)` operator receives each
    /// random value only one time, and then sends the value to both subscribers.
    ///
    /// - Parameter createSubject: A closure to create a new `Subject` each time
    ///   a subscriber attaches to the multicast publisher.
    public func multicast<SubjectType: Subject>(
        _ createSubject: @escaping () -> SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
    where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return Publishers.Multicast(upstream: self, createSubject: createSubject)
    }
    
    /// Provides a subject to deliver elements to multiple subscribers.
    ///
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    /// This is useful when upstream publishers are doing expensive work you don’t want
    /// to duplicate, like performing network requests.
    ///
    /// In contrast with `multicast(_:)`, this method produces a publisher that shares
    /// the provided `Subject` among all the downstream subscribers.
    ///
    /// The following example uses a sequence publisher as a counter to publish three
    /// random numbers, generated by a `map(_:)` operator.
    /// It uses a `multicast(subject:)` operator with a `PassthroughSubject` to share
    /// the same random number to each of two subscribers. Because the multicast publisher
    /// is a `ConnectablePublisher`, publishing only begins after a call to `connect()`.
    ///
    ///     let pub = ["First", "Second", "Third"].publisher
    ///         .map( { return ($0, Int.random(in: 0...100)) } )
    ///         .print("Random")
    ///         .multicast(subject: PassthroughSubject<(String, Int), Never>())
    ///
    ///     cancellable1 = pub
    ///         .sink { print ("Stream 1 received: \($0)")}
    ///     cancellable2 = pub
    ///         .sink { print ("Stream 2 received: \($0)")}
    ///     pub.connect()
    ///
    ///     // Prints:
    ///     // Random: receive value: (("First", 78))
    ///     // Stream 2 received: ("First", 78)
    ///     // Stream 1 received: ("First", 78)
    ///     // Random: receive value: (("Second", 98))
    ///     // Stream 2 received: ("Second", 98)
    ///     // Stream 1 received: ("Second", 98)
    ///     // Random: receive value: (("Third", 61))
    ///     // Stream 2 received: ("Third", 61)
    ///     // Stream 1 received: ("Third", 61)
    ///
    /// In this example, the output shows that the `print(_:to:)` operator receives each
    /// random value only one time, and then sends the value to both subscribers.
    ///
    /// - Parameter subject: A subject to deliver elements to downstream subscribers.
    public func multicast<SubjectType: Subject>(
        subject: SubjectType
    ) -> Publishers.Multicast<Self, SubjectType>
    where Failure == SubjectType.Failure, Output == SubjectType.Output
    {
        return multicast { subject }
    }
}

extension Publishers {
    
    /// A publisher that uses a subject to deliver elements to multiple subscribers.
    ///
    /// Use a multicast publisher when you have multiple downstream subscribers, but you
    /// want upstream publishers to only process one `receive(_:)` call per event.
    public final class Multicast<Upstream: Publisher, SubjectType: Subject>
    : ConnectablePublisher
    where Upstream.Failure == SubjectType.Failure,
          Upstream.Output == SubjectType.Output
    {
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher that this publisher receives elements from.
        public let upstream: Upstream
        
        /// A closure to create a new Subject each time a subscriber attaches
        /// to the multicast publisher.
        public let createSubject: () -> SubjectType
        
        private let lock = UnfairLock.allocate()
        
        private var subject: SubjectType?
        
        private var lazySubject: SubjectType {
            lock.lock()
            if let subject = subject {
                lock.unlock()
                return subject
            }
            
            let subject = createSubject()
            self.subject = subject
            lock.unlock()
            return subject
        }
        
        /// Creates a multicast publisher that applies a closure to create a subject that
        /// delivers elements to subscribers.
        ///
        /// - Parameter createSubject: A closure that returns a `Subject` each time
        ///   a subscriber attaches to the multicast publisher.
        public init(upstream: Upstream, createSubject: @escaping () -> SubjectType) {
            self.upstream = upstream
            self.createSubject = createSubject
        }
        
        deinit {
            lock.deallocate()
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where SubjectType.Failure == Downstream.Failure,
              SubjectType.Output == Downstream.Input
        {
            lazySubject.subscribe(Inner(parent: self, downstream: subscriber))
        }
        
        public func connect() -> Cancellable {
            return upstream.subscribe(lazySubject)
        }
    }
}

extension Publishers.Multicast {
    
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Upstream.Output == Downstream.Input, Upstream.Failure == Downstream.Failure
    {
        // NOTE: This class has been audited for thread safety
        
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private enum State {
            case ready(upstream: Upstream, downstream: Downstream)
            case subscribed(upstream: Upstream,
                            downstream: Downstream,
                            subjectSubscription: Subscription)
            case terminal
        }
        
        private let lock = UnfairLock.allocate()
        
        private var state: State
        
        fileprivate init(parent: Publishers.Multicast<Upstream, SubjectType>,
                         downstream: Downstream) {
            state = .ready(upstream: parent.upstream, downstream: downstream)
        }
        
        deinit {
            lock.deallocate()
        }
        
        fileprivate var description: String { return "Multicast" }
        
        fileprivate var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        fileprivate var playgroundDescription: Any { return description }
        
        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(upstream, downstream) = state else {
                lock.unlock()
                subscription.cancel()
                return
            }
            state = .subscribed(upstream: upstream,
                                downstream: downstream,
                                subjectSubscription: subscription)
            lock.unlock()
            downstream.receive(subscription: self)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .subscribed(_, downstream, subjectSubscription) = state else {
                lock.unlock()
                return .none
            }
            lock.unlock()
            let newDemand = downstream.receive(input)
            if newDemand > 0 {
                subjectSubscription.request(newDemand)
            }
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .subscribed(_, downstream, _) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            lock.unlock()
            subjectSubscription.request(demand)
        }
        
        func cancel() {
            lock.lock()
            guard case let .subscribed(_, _, subjectSubscription) = state else {
                lock.unlock()
                return
            }
            state = .terminal
            lock.unlock()
            subjectSubscription.cancel()
        }
    }
}
