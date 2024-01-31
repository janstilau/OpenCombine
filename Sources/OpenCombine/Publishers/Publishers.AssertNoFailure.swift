extension Publisher {
    
    /// Raises a fatal error when its upstream publisher fails, and otherwise republishes
    /// all received input.
    ///
    /// Use `assertNoFailure()` for internal sanity checks that are active during testing.
    /// However, it is important to note that, like its Swift counterpart
    /// `fatalError(_:)`, the `assertNoFailure()` operator asserts a fatal exception when
    /// triggered in both development/testing _and_ shipping versions of code.
    ///
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
    ///
    ///     // Prints:
    ///     //  value: initial value.
    ///     //  value: second value.
    ///     // The process then terminates in the debugger as the assertNoFailure
    ///     // operator catches the genericSubjectError.
    ///
    /// - Parameters:
    ///   - prefix: A string used at the beginning of the fatal error message.
    ///   - file: A filename used in the error message. This defaults to `#file`.
    ///   - line: A line number used in the error message. This defaults to `#line`.
    /// - Returns: A publisher that raises a fatal error when its upstream publisher
    ///   fails.
    /// 当上游发布者失败时，触发致命错误，否则重新发布所有接收到的输入。
    ///
    /// 在测试期间激活的内部合理性检查中使用 `assertNoFailure()`。然而，值得注意的是，类似于其 Swift 对应物 `fatalError(_:)`，
    /// `assertNoFailure()` 操作符在开发/测试版本的代码和发布版本中触发时都会断言致命异常。
    ///
    /// 在下面的示例中，一个 `CurrentValueSubject` 成功发布了初始值和第二个值。
    /// 第三个值，包含一个 `genericSubjectError`，导致 `assertNoFailure()` 操作符触发致命异常停止进程：
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
    ///
    ///     // 打印:
    ///     //  value: initial value.
    ///     //  value: second value.
    ///     // 然后，在断言 `assertNoFailure` 捕捉到 `genericSubjectError` 时，进程终止。
    ///
    /// - Parameters:
    ///   - prefix: 在致命错误消息开头使用的字符串。
    ///   - file: 在错误消息中使用的文件名，默认为 `#file`。
    ///   - line: 在错误消息中使用的行号，默认为 `#line`。
    /// - Returns: 一个发布者，在其上游发布者

    public func assertNoFailure(_ prefix: String = "",
                                file: StaticString = #file,
                                line: UInt = #line) -> Publishers.AssertNoFailure<Self> {
        return .init(upstream: self, prefix: prefix, file: file, line: line)
    }
}

extension Publishers {
    
    /// A publisher that raises a fatal error upon receiving any failure, and otherwise
    /// republishes all received input.
    ///
    /// Use this function for internal sanity checks that are active during testing but
    /// do not impact performance of shipping code.
    public struct AssertNoFailure<Upstream: Publisher>: Publisher {
        
        public typealias Output = Upstream.Output
        
        // 最为关键的一点, 就是 Failure 变为了 Never.
        // 这样的话, 才能对接后续的 Subscriber, 例如 assignOn, Complte.
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
        
        // 还是会承接, 上游的数据, 但是不给下游数据. 直接崩溃.
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
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            return downstream.receive(input)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            switch completion {
            case .finished:
                downstream.receive(completion: .finished)
            case .failure(let error):
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
