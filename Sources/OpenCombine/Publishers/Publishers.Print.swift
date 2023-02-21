
/*
 
 /// A type that can be the target of text-streaming operations.
 ///
 /// You can send the output of the standard library's `print(_:to:)` and
 /// `dump(_:to:)` functions to an instance of a type that conforms to the
 /// `TextOutputStream` protocol instead of to standard output.
 /// Swift's `String` type conforms to `TextOutputStream` already, so you can capture
 /// the output from `print(_:to:)` and `dump(_:to:)` in a string instead of
 /// logging it to standard output.
 ///
 ///     var s = ""
 ///     for n in 1...5 {
 // 和其他语言的 Sprint 的用法是一样的.
 ///         print(n, terminator: "", to: &s)
 ///     }
 ///     // s == "12345"
 ///
 /// Conforming to the TextOutputStream Protocol
 /// ===========================================
 ///
 /// To make your custom type conform to the `TextOutputStream` protocol,
 /// implement the required `write(_:)` method. Functions that use a
 /// `TextOutputStream` target may call `write(_:)` multiple times per writing
 /// operation.
 ///
 /// As an example, here's an implementation of an output stream that converts
 /// any input to its plain ASCII representation before sending it to standard
 /// output.
 ///
 ///     struct ASCIILogger: TextOutputStream {
 ///         mutating func write(_ string: String) {
 ///             let ascii = string.unicodeScalars.lazy.map { scalar in
 ///                 scalar == "\n"
 ///                   ? "\n"
 ///                   : scalar.escaped(asASCII: true)
 ///             }
 ///             print(ascii.joined(separator: ""), terminator: "")
 ///         }
 ///     }
 ///
 /// The `ASCIILogger` type's `write(_:)` method processes its string input by
 /// escaping each Unicode scalar, with the exception of `"\n"` line returns.
 /// By sending the output of the `print(_:to:)` function to an instance of
 /// `ASCIILogger`, you invoke its `write(_:)` method.
 ///
 ///     let s = "Hearts ♡ and Diamonds ♢"
 ///     print(s)
 ///     // Prints "Hearts ♡ and Diamonds ♢"
 ///
 ///     var asciiLogger = ASCIILogger()
 ///     print(s, to: &asciiLogger)
 ///     // Prints "Hearts \u{2661} and Diamonds \u{2662}"
 
 能够, 接受字符串进行输出的抽象.
 在别人的示例中, 看到过这样的写法, 原来是系统就已经构建出来的抽象
 public protocol TextOutputStream {
 
 /// Appends the given string to the stream.
 mutating func write(_ string: String)
 }
 */
extension Publisher {
    
    /// Prints log messages for all publishing events.
    ///
    /// Use `print(_:to:)` to log messages the console.
    
    /// In the example below, log messages are printed on the console:
    ///
    ///     let integers = (1...2)
    ///     cancellable = integers.publisher
    ///        .print("Logged a message", to: nil)
    ///        .sink { _ in }
    ///
    ///     // Prints:
    ///     // 接收到了上游的节点
    ///     //  Logged a message: receive subscription: (1..<2)
    ///     // 接受到了下游节点的需求
    ///     //  Logged a message: request unlimited
    ///     // 接收到了上游的数据
    ///     //  Logged a message: receive value: (1)
    ///     // 接收到了上游的完成事件
    ///     //  Logged a message: receive finished
    
    /// - Parameters:
    ///   - prefix: A string — which defaults to empty — with which to prefix all log
    ///     messages.
    ///   - stream: A stream for text output that receives messages, and which directs
    ///     output to the console by default.  A custom stream can be used to log messages
    ///     to other destinations.
    /// - Returns: A publisher that prints log messages for all publishing events.
    public func print(_ prefix: String = "",
                      to stream: TextOutputStream? = nil) -> Publishers.Print<Self> {
        return .init(upstream: self, prefix: prefix, to: stream)
    }
}

extension Publishers {
    
    // 一个完全的中介节点, 不会对数据的传播, 有任何的改变. 仅仅是在其中, 增加了 Log 的打印.
    // 所以, 在它的各个函数里面, 是 Log 业务代码, + forward 相关的代码.
    /// A publisher that prints log messages for all publishing events, optionally
    /// prefixed with a given string.
    ///
    /// This publisher prints log messages when receiving the following events:
    // 在各个相关的代码里面, 进行了 Log 的注册.
    /// - subscription
    /// - value
    /// - normal completion
    /// - failure
    /// - cancellation
    
    // 一个 Publisher, 它的任务, 其实就是业务信息的收集. 真正的信息流的处理, 其实是生成的 Inner 对象来处理的.
    public struct Print<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Upstream.Failure
        
        /// A string with which to prefix all log messages.
        public let prefix: String
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        public let stream: TextOutputStream?
        
        /// Creates a publisher that prints log messages for all publishing events.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - prefix: A string with which to prefix all log messages.
        public init(upstream: Upstream,
                    prefix: String,
                    to stream: TextOutputStream? = nil) {
            self.upstream = upstream
            self.prefix = prefix
            self.stream = stream
        }
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Output == Downstream.Input
        {
            // 生成 Inner 对象, 将各种数据复制过去, 做真正的响应链的搭建.
            let inner = Inner(downstream: subscriber, prefix: prefix, stream: stream)
            upstream.subscribe(inner)
        }
    }
}

extension Publishers.Print {
    
    /*
     之所以, 要是一个 Subscriber, 是因为 Print.Inner 是一个中间节点, 他要接收到上游的数据.
     之所以, 要是一个 Subscription, 是因为 Print.Inner 是一个中间节点, 他要接受下游的 Request Demand 做背压管理, 也要接受啊 cancel 来响应下游的取消操作.
     */
    private final class Inner<Downstream: Subscriber>: Subscriber,
                                                       Subscription,
                                                       CustomStringConvertible,
                                                       CustomReflectable,
                                                       CustomPlaygroundDisplayConvertible
    {
        typealias Input = Downstream.Input
        typealias Failure = Downstream.Failure
        
        /// A concrete type wrapper around an abstract stream.
        private struct PrintTarget: TextOutputStream {
            
            var stream: TextOutputStream
            
            mutating func write(_ string: String) {
                stream.write(string)
            }
        }
        
        private var downstream: Downstream
        private let prefix: String
        private var stream: PrintTarget?
        // 几乎每个中间节点, 都有这样的一个状态值.
        // 这个状态值, 做了状态管理和 Subscription 记录两件事.
        private var status = SubscriptionStatus.awaitingSubscription
        private let lock = UnfairLock.allocate()
        
        init(downstream: Downstream, prefix: String, stream: TextOutputStream?) {
            self.downstream = downstream
            self.prefix = prefix.isEmpty ? "" : "\(prefix): "
            // Map 是 Optinal 的 Map.
            // 在这些流行库里面, 把方法当做闭包来传递, 是一个非常常见的写法.
            self.stream = stream.map(PrintTarget.init)
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 在各种事件中, 增加了对应的 Log, 然后保持原有的逻辑不变.
        // 在 receive(subscription 中, 进行状态的管理, 形成了循环引用. 然后, 将自己作为下游的 subscription 传递给下游的节点 .
        // 这是最标准的 Operator 的做法.
        func receive(subscription: Subscription) {
            log("\(prefix)receive subscription: (\(subscription))")
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
        
        // 在真正的接收到 Value 的函数里面, 触发自身的业务逻辑, 然后将得到的结果传递给下游节点.
        // 将收到的数据, 传递给下游节点, 这是每个 Operator 都必须要做的一点.
        func receive(_ input: Input) -> Subscribers.Demand {
            log("\(prefix)receive value: (\(input))")
            let demand = downstream.receive(input)
            
            if let max = demand.max {
                log("\(prefix)request max: (\(max)) (synchronous)")
            } else {
                log("\(prefix)request unlimited (synchronous)")
            }
            
            return demand
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                log("\(prefix)receive finished")
            case .failure(let error):
                log("\(prefix)receive error: (\(error))")
            }
            lock.lock()
            status = .terminal
            lock.unlock()
            // 更新自身的状态, 然后调用下游的 receive(completion, 这是最标准的 Operator 的做法
            downstream.receive(completion: completion)
        }
        
        func request(_ demand: Subscribers.Demand) {
            if let max = demand.max {
                log("\(prefix)request max: (\(max))")
            } else {
                log("\(prefix)request unlimited")
            }
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            lock.unlock()
            
            // 透传.
            subscription.request(demand)
        }
        
        func cancel() {
            log("\(prefix)receive cancel")
            lock.lock()
            guard case let .subscribed(subscription) = status else {
                lock.unlock()
                return
            }
            // 惯例实现.
            status = .terminal
            lock.unlock()
            subscription.cancel()
        }
        
        
        
        
        var description: String { return "Print" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
        
        // MARK: - Private
        
        // 在这里, 做了 PrintTarget 的指定.
        private func log(_ text: String) {
            if var stream = stream {
                Swift.print(text, to: &stream)
            } else {
                Swift.print(text)
            }
        }
    }
}
