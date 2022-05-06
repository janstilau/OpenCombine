
extension Publisher {
    
    /// Attempts to recreate a failed subscription with the upstream publisher up to
    /// the number of times you specify.
    
    /// Use `retry(_:)` to try connecting to an upstream publisher after a failed
    /// connection attempt.
    
    /// In the example below, a `URLSession.DataTaskPublisher` attempts to connect to
    /// a remote URL. If the connection attempt succeeds, it publishes the remote
    /// service’s HTML to the downstream publisher and completes normally. Otherwise,
    /// the retry operator attempts to reestablish the connection. If after three attempts
    /// the publisher still can’t connect to the remote URL, the `catch(_:)` operator
    /// replaces the error with a new publisher that publishes a “connection timed out”
    /// HTML page. After the downstream subscriber receives the timed out message,
    /// the stream completes normally.
    ///
    ///     struct WebSiteData: Codable {
    ///         var rawHTML: String
    ///     }
    ///
    ///     let myURL = URL(string: "https://www.example.com")
    ///
    ///     cancellable = URLSession.shared.dataTaskPublisher(for: myURL!)
    ///         .retry(3)
    ///         .map { page -> WebSiteData in
    ///             WebSiteData(rawHTML: String(decoding: page.data, as: UTF8.self))
    ///         }
    ///         .catch { error in
    ///             Just(
    ///                 WebSiteData(
    ///                     rawHTML: "<HTML>Unable to load page - timed out.</HTML>"
    ///                 )
    ///             )
    ///         }
    ///         .sink(receiveCompletion: { print ("completion: \($0)") },
    ///               receiveValue: { print ("value: \($0)") })
    ///
    ///     // Prints: The HTML content from the remote URL upon a successful connection,
    ///     //         or returns "<HTML>Unable to load page - timed out.</HTML>" if
    ///     //         the number of retries exceeds the specified value.
    ///
    /// After exceeding the specified number of retries, the publisher passes the failure
    /// to the downstream receiver.
    /// - Parameter retries: The number of times to attempt to recreate the subscription.
    /// - Returns: A publisher that attempts to recreate its subscription to a failed
    ///   upstream publisher.
    public func retry(_ retries: Int) -> Publishers.Retry<Self> {
        return .init(upstream: self, retries: retries)
    }
}

extension Publishers {
    
    /// A publisher that attempts to recreate its subscription to a failed upstream
    /// publisher.
    public struct Retry<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The maximum number of retry attempts to perform.
        ///
        /// If `nil`, this publisher attempts to reconnect with the upstream publisher
        /// an unlimited number of times.
        // 这个值, 一定要设置, 不然无限重链.
        public let retries: Int?
        
        /// Creates a publisher that attempts to recreate its subscription to a failed
        /// upstream publisher.
        /// 惯例,  信息收集.
        public init(upstream: Upstream, retries: Int?) {
            self.upstream = upstream
            self.retries = retries
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Failure
        {
            upstream.subscribe(Inner(parent: self, downstream: subscriber))
        }
    }
}

extension Publishers.Retry: Equatable where Upstream: Equatable {}

extension Publishers.Retry {
    // 真正的 Retry 所生成的链接节点.
    private final class Inner<Downstream: Subscriber>
    : Subscriber,
      Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Failure == Failure, Downstream.Input == Output
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        // 使用了 Enum, 做更好的状态管理.
        private enum State {
            case ready(Publishers.Retry<Upstream>, Downstream)
            case terminal
        }
        
        private enum Chances {
            case finite(Int)
            case infinite
        }
        
        private let lock = UnfairLock.allocate()
        
        private var state: State
        
        // 上游节点, 可以变化.
        private var upstreamSubscription: Subscription?
        
        // 重试次数.
        private var remaining: Chances
        
        private var downstreamNeedsSubscription = true
        
        private var downstreamDemand = Subscribers.Demand.none
        
        private var completionRecursion = false
        
        private var needsSubscribe = false
        
        // 初始化, 主要是信息的收集.
        init(parent: Publishers.Retry<Upstream>, downstream: Downstream) {
            state = .ready(parent, downstream)
            // 这里的 Map, 是 optinal 的 Map.
            remaining = parent.retries.map(Chances.finite) ?? .infinite
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 这个函数, 会被多次调用.
        // 因为上游 failed 之后, 会重新 parent.upstream.subscribe(self)
        // 这个时候, 而这个过程, 会重新触发上游节点的创建, 所以, 传递进来的就是一个新的 Subscription 对象.
        func receive(subscription: Subscription) {
            lock.lock()
            guard case let .ready(_, downstream) = state,
                    upstreamSubscription == nil else {
                lock.unlock()
                subscription.cancel()
                return
            }
            
            // 存储上游节点.
            upstreamSubscription = subscription
            let downstreamDemand = self.downstreamDemand
            /*
             self.downstreamNeedsSubscription 用来控制, 下游节点, 只会收到一次 Retry 生成的节点.
             */
            let downstreamNeedsSubscription = self.downstreamNeedsSubscription
            self.downstreamNeedsSubscription = false
            lock.unlock()
            if downstreamNeedsSubscription {
                downstream.receive(subscription: self)
            }
            // self.downstreamDemand 有值, 应该是已经失败的 Subscription 触发的下游的 Demand 需求.
            // 当一个新的 Subscription 来临之后, 还是需要使用现有的 Demand 的值, 触发上游的相关信号生成逻辑的触发.
            if downstreamDemand != .none {
                subscription.request(downstreamDemand)
            }
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            lock.lock()
            guard case let .ready(_, downstream) = state else {
                lock.unlock()
                return .none
            }
            downstreamDemand -= 1
            lock.unlock()
            
            // 传输数据.
            let newDemand = downstream.receive(input)
            
            if newDemand == .none { return .none }
            
            lock.lock()
            downstreamDemand += newDemand
            
            if let upstreamSubscription = self.upstreamSubscription {
                lock.unlock()
                // 向上游要求更多的数据.
                upstreamSubscription.request(newDemand)
            } else {
                lock.unlock()
            }
            
            return .none
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            lock.lock()
            guard case let .ready(parent, downstream) = state else {
                lock.unlock()
                return
            }
            
            // 如果, 失败了
            if case .failure = completion {
                // 上游放弃. 这个上游应该自己把资源释放了.
                upstreamSubscription = nil
                switch remaining {
                case .finite(0):
                    // 没有机会了. 给后续节点传输失败.
                    break
                case .finite(let attempts):
                    // 管理 remain 的次数.
                    remaining = .finite(attempts - 1)
                    fallthrough
                case .infinite:
                    if completionRecursion {
                        needsSubscribe = true
                        lock.unlock()
                        return
                    }
                    repeat {
                        completionRecursion = true
                        needsSubscribe = false
                        lock.unlock()
                        // 再次使用上游节点, 进行 attach 的动作.
                        // 这个时候, parent.upstream 会重新生成对应的 Subscription 节点, 然后和 Self 进行 Attach 的操作.
                        parent.upstream.subscribe(self)
                        lock.lock()
                        completionRecursion = false
                    } while needsSubscribe
                    lock.unlock()
                    return
                }
            }
            
            // 如果是正常的结束事件, 管理状态和数据, 向后进行 Forward
            state = .terminal
            lock.unlock()
            downstream.receive(completion: completion)
        }
        
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard case .ready = state else {
                lock.unlock()
                return
            }
            downstreamDemand += demand
            if let upstreamSubscription = self.upstreamSubscription {
                lock.unlock()
                upstreamSubscription.request(demand)
            } else {
                lock.unlock()
            }
        }
        
        func cancel() {
            lock.lock()
            guard case .ready = state else {
                lock.unlock()
                return
            }
            state = .terminal
            if let upstreamSubscription = self.upstreamSubscription {
                lock.unlock()
                upstreamSubscription.cancel()
            } else {
                lock.unlock()
            }
        }
        
        var description: String { return "Retry" }
        
        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }
        
        var playgroundDescription: Any { return description }
    }
}
