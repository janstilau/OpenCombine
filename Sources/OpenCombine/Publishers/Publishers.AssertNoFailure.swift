
// 消除错误的. 专门的一个 Publisher, 使得上游节点的 Failure 类型变为 Never.
extension Publisher {
    
    /// Raises a fatal error when its upstream publisher fails, and otherwise republishes
    /// all received input.
    // 如果上游出错了, 直接崩. 如果没有, 直接 forward 上游的任何事件.
    
    /// Use `assertNoFailure()` for internal sanity checks that are active during testing.
    /// However, it is important to note that, like its Swift counterpart
    
    /// `fatalError(_:)`, the `assertNoFailure()` operator asserts a fatal exception when
    /// triggered in both development/testing _and_ shipping versions of code.
    
    
    /// In the example below, a `CurrentValueSubject` publishes the initial and second
    /// values successfully. The third value, containing a `genericSubjectError`, causes
    /// the `assertNoFailure()` operator to assert a fatal exception stopping the process:
    ///
    ///     public enum SubjectError: Error {
    ///         case genericSubjectError
    ///     }
    ///
    ///     let subject = CurrentValueSubject<String, Error>("initial value")
    ///     subject
    ///         .assertNoFailure()
    ///         .sink(receiveCompletion: { print ("completion: \($0)") },
    ///               receiveValue: { print ("value: \($0).") }
    ///         )
    ///
    ///     subject.send("second value")
    ///     subject.send(completion: .failure(SubjectError.genericSubjectError))
    
    
    ///     // Prints:
    ///     //  value: initial value.
    ///     //  value: second value.
    ///     // The process then terminates in the debugger as the assertNoFailure
    ///     // operator catches the genericSubjectError.
    /// - Returns: A publisher that raises a fatal error when its upstream publisher
    ///   fails.
    public func assertNoFailure(_ prefix: String = "",
                                file: StaticString = #file,
                                line: UInt = #line) -> Publishers.AssertNoFailure<Self> {
        return .init(upstream: self, prefix: prefix, file: file, line: line)
    }
}

extension Publishers {
    /// A publisher that raises a fatal error upon receiving any failure, and otherwise republishes all received input.
    /// Use this function for internal sanity checks that are active during testing but do not impact performance of shipping code.
    public struct AssertNoFailure<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        public typealias Failure = Never
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The string used at the beginning of the fatal error message.
        public let prefix: String
        
        /// The filename used in the error message.
        public let file: StaticString
        
        /// The line number used in the error message.
        public let line: UInt
        
        public init(upstream: Upstream, prefix: String, file: StaticString, line: UInt) {
            self.upstream = upstream
            self.prefix = prefix
            self.file = file
            self.line = line
        }
        
        // 通用的设计思路. 实际上, 还是中间插入了一个节点. 因为有这个节点在, 将上游的 Error 抹除到 Never 类型.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Downstream.Input == Output, Downstream.Failure == Never
        {
            upstream.subscribe(Inner(downstream: subscriber,
                                     prefix: prefix,
                                     file: file,
                                     line: line))
        }
    }
}

extension Publishers.AssertNoFailure {
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Upstream.Output, Downstream.Failure == Never
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let prefix: String
        
        private let file: StaticString
        
        private let line: UInt
        
        let combineIdentifier = CombineIdentifier()
        
        init(downstream: Downstream, prefix: String, file: StaticString, line: UInt) {
            self.downstream = downstream
            self.prefix = prefix
            self.file = file
            self.line = line
        }
        
        // 全部, 都是移交动作.
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }
        
        // 这个节点, 真正需要处理的就是 Completion 事件. 如果上游节点发生了错误, 就报错. 
        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
                // 如果, 接收到的是 Error, 直接就崩了.
                // 通过这种机制, 使得下游节点可以确定, 上游节点是没有 Error 的.
                let prefix = self.prefix.isEmpty ? "" : self.prefix + ": "
                fatalError("\(prefix)\(error)", file: file, line: line)
            }
        }
        
        var description: String { return "AssertNoFailure" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("file", file),
                ("line", line),
                ("prefix", prefix)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
