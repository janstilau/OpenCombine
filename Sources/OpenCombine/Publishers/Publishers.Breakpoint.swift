//
//  Publishers.Breakpoint.swift
//  
//
//  Created by Sergej Jaskiewicz on 03.12.2019.
//

#if !WASI

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

extension Publisher {

    /// Raises a debugger signal when a provided closure needs to stop the process in
    /// the debugger.
    ///
    /// Use `breakpoint(receiveSubscription:receiveOutput:receiveCompletion:)` to examine
    /// one or more stages of the subscribe/publish/completion process and stop in 在建立链接, 发送数据, 以及完成事件流的时候, 都会触发 debugger.
    /// the debugger, based on conditions you specify. When any of the provided closures
    /// returns `true`, this operator raises the `SIGTRAP` signal to stop the process
    /// in the debugger. Otherwise, this publisher passes through values and completions
    /// as-is.
    
    
    /// In the example below, a `PassthroughSubject` publishes strings to a breakpoint
    /// republisher. When the breakpoint receives the string “`DEBUGGER`”, it returns
    /// `true`, which stops the app in the debugger.
    ///
    ///     let publisher = PassthroughSubject<String?, Never>()
    ///     cancellable = publisher
    ///         .breakpoint(
    ///             receiveOutput: { value in return value == "DEBUGGER" }
    ///         )
    ///         .sink { print("\(String(describing: $0))" , terminator: " ") }
    ///
    ///     publisher.send("DEBUGGER")
    ///
    ///     // Prints: "error: Execution was interrupted, reason: signal SIGTRAP."
    ///     // Depending on your specific environment, the console messages may
    ///     // also include stack trace information, which is not shown here.
    ///
    /// - Parameters:
    ///   - receiveSubscription: A closure that executes when when the publisher receives
    ///     a subscription. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    ///   - receiveOutput: A closure that executes when when the publisher receives
    ///     a value. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    ///   - receiveCompletion: A closure that executes when when the publisher receives
    ///     a completion. Return `true` from this closure to raise `SIGTRAP`, or `false`
    ///     to continue.
    /// - Returns: A publisher that raises a debugger signal when one of the provided
    ///   closures returns `true`.
    /// 当提供的闭包需要在调试器中停止进程时，触发调试器信号的操作符。
    ///
    /// 使用 `breakpoint(receiveSubscription:receiveOutput:receiveCompletion:)` 来检查
    /// 订阅/发布/完成过程的一个或多个阶段，并根据你指定的条件在调试器中停止。当任何提供的闭包
    /// 返回 `true` 时，此操作符将触发 `SIGTRAP` 信号以在调试器中停止进程。否则，此发布者将值和
    /// 完成事件原样传递。
    ///
    /// 在下面的示例中，`PassthroughSubject` 发布字符串到断点复制器。当断点接收到字符串“`DEBUGGER`”时，
    /// 它返回 `true`，从而在调试器中停止应用程序。
    ///
    ///     let publisher = PassthroughSubject<String?, Never>()
    ///     cancellable = publisher
    ///         .breakpoint(
    ///             receiveOutput: { value in return value == "DEBUGGER" }
    ///         )
    ///         .sink { print("\(String(describing: $0))" , terminator: " ") }
    ///
    ///     publisher.send("DEBUGGER")
    ///
    ///     // 输出: "error: Execution was interrupted, reason: signal SIGTRAP."
    ///     // 根据你的特定环境，控制台消息可能还包括堆栈跟踪信息，这里没有显示。
    ///
    /// - Parameters:
    ///   - receiveSubscription: 当发布者接收到订阅时执行的闭包。从此闭包返回 `true` 以触发 `SIGTRAP`，或返回 `false` 以继续。
    ///   - receiveOutput: 当发布者接收到值时执行的闭包。从此闭包返回 `true` 以触发 `SIGTRAP`，或返回 `false` 以继续。
    ///   - receiveCompletion: 当发布者接收到完成事件时执行的闭包。从此闭包返回 `true` 以触发 `SIGTRAP`，或返回 `false` 以继续。
    /// - Returns: 一个发布者，当提供的闭包之一返回 `true` 时，触发调试器信号。

    public func breakpoint(
        receiveSubscription: ((Subscription) -> Bool)? = nil,
        receiveOutput: ((Output) -> Bool)? = nil,
        receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil
    ) -> Publishers.Breakpoint<Self> {
        return .init(upstream: self,
                     receiveSubscription: receiveSubscription,
                     receiveOutput: receiveOutput,
                     receiveCompletion: receiveCompletion)
    }

    /// Raises a debugger signal upon receiving a failure.
    ///
    /// When the upstream publisher fails with an error, this publisher raises
    /// the `SIGTRAP` signal, which stops the process in the debugger. Otherwise, this
    /// publisher passes through values and completions as-is.
    ///
    /// In this example a `PassthroughSubject` publishes strings, but its downstream
    /// `Publisher/tryMap(_:)` operator throws an error. This sends the error downstream
    /// as a `Subscribers.Completion.failure(_:)`. The `breakpointOnError()`
    /// operator receives this completion and stops the app in the debugger.
    ///
    ///      struct CustomError : Error {}
    ///      let publisher = PassthroughSubject<String?, Error>()
    ///      cancellable = publisher
    ///          .tryMap { stringValue in
    ///              throw CustomError()
    ///          }
    ///          .breakpointOnError()
    ///          .sink(
    ///              receiveCompletion: { completion in
    ///                  print("Completion: \(String(describing: completion))")
    ///              },
    ///              receiveValue: { aValue in
    ///                  print("Result: \(String(describing: aValue))")
    ///              }
    ///          )
    ///
    ///      publisher.send("TEST DATA")
    ///
    ///      // Prints: "error: Execution was interrupted, reason: signal SIGTRAP."
    ///      // Depending on your specific environment, the console messages may
    ///      // also include stack trace information, which is not shown here.
    ///
    /// - Returns: A publisher that raises a debugger signal upon receiving a failure.
    // 对于 breakpoint 操作符的封装, 当上游出错的时候, 才会触发断点.
    public func breakpointOnError() -> Publishers.Breakpoint<Self> {
        return breakpoint(receiveCompletion: { completion in
            switch completion {
            case .finished:
                return false
            case .failure:
                return true
            }
        })
    }
}

extension Publishers {

    /// A publisher that raises a debugger signal when a provided closure needs to stop
    /// the process in the debugger.
    ///
    /// When any of the provided closures returns `true`, this publisher raises
    /// the `SIGTRAP` signal to stop the process in the debugger.
    /// Otherwise, this publisher passes through values and completions as-is.
    public struct Breakpoint<Upstream: Publisher>: Publisher {

        public typealias Output = Upstream.Output

        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// A closure that executes when the publisher receives a subscription, and can
        /// raise a debugger signal by returning a `true` Boolean value.
        public let receiveSubscription: ((Subscription) -> Bool)?

        /// A closure that executes when the publisher receives output from the upstream
        /// publisher, and can raise a debugger signal by returning a `true` Boolean
        /// value.
        public let receiveOutput: ((Upstream.Output) -> Bool)?

        /// A closure that executes when the publisher receives completion, and can raise
        /// a debugger signal by returning a `true` Boolean value.
        public let receiveCompletion:
            ((Subscribers.Completion<Upstream.Failure>) -> Bool)?

        /// Creates a breakpoint publisher with the provided upstream publisher and
        /// breakpoint-raising closures.
        ///
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        ///   - receiveSubscription: A closure that executes when the publisher receives
        ///     a subscription, and can raise a debugger signal by returning a `true`
        ///     Boolean value.
        ///   - receiveOutput: A closure that executes when the publisher receives output
        ///     from the upstream publisher, and can raise a debugger signal by returning
        ///     a `true` Boolean value.
        ///   - receiveCompletion: A closure that executes when the publisher receives
        ///     completion, and can raise a debugger signal by returning a `true` Boolean
        ///     value.
        public init(
            upstream: Upstream,
            receiveSubscription: ((Subscription) -> Bool)? = nil,
            receiveOutput: ((Upstream.Output) -> Bool)? = nil,
            receiveCompletion: ((Subscribers.Completion<Failure>) -> Bool)? = nil
        ) {
            self.upstream = upstream
            self.receiveSubscription = receiveSubscription
            self.receiveOutput = receiveOutput
            self.receiveCompletion = receiveCompletion
        }

        public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Upstream.Failure == Downstream.Failure,
                  Upstream.Output == Downstream.Input
        {
            upstream.subscribe(Inner(self, downstream: subscriber))
        }
    }
}

extension Publishers.Breakpoint {
    // 这个 HandleEvent 其实是一个原理. 只不过, 这里传入的是断点触发的 block, 在各个事件节点, 使用这些 block 来进行断点的触发.
    private struct Inner<Downstream: Subscriber>
        : Subscriber,
          CustomStringConvertible,
          CustomReflectable,
          CustomPlaygroundDisplayConvertible
        where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        typealias Failure = Upstream.Failure

        private let downstream: Downstream
        private let breakpoint: Publishers.Breakpoint<Upstream>

        let combineIdentifier = CombineIdentifier()

        init(_ breakpoint: Publishers.Breakpoint<Upstream>,
             downstream: Downstream) {
            self.downstream = downstream
            self.breakpoint = breakpoint
        }

        // 安插了一个中间节点, 透传, 然后会根据 block 的返回值, 来触发是否断点了. 
        func receive(subscription: Subscription) {
            if breakpoint.receiveSubscription?(subscription) == true {
                __stopInDebugger()
            }
            downstream.receive(subscription: subscription)
        }

        func receive(_ input: Upstream.Output) -> Subscribers.Demand {
            if breakpoint.receiveOutput?(input) == true {
                __stopInDebugger()
            }
            return downstream.receive(input)
        }

        func receive(completion: Subscribers.Completion<Upstream.Failure>) {
            if breakpoint.receiveCompletion?(completion) == true {
                __stopInDebugger()
            }
            downstream.receive(completion: completion)
        }

        var description: String { return "Breakpoint" }

        var customMirror: Mirror {
            return Mirror(self, children: EmptyCollection())
        }

        var playgroundDescription: Any { return description }
    }
}

#endif // !WASI
