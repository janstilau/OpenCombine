
// 直接发送错误, 这在组建复杂逻辑的时候, 是很好用的小部件.
/// A publisher that immediately terminates with the specified error.
public struct Fail<Output, Failure: Error>: Publisher {
    
    /// Creates a publisher that immediately terminates with the specified failure.
    /// - Parameter error: The failure to send when terminating the publisher.
    public init(error: Failure) {
        self.error = error
    }
    
    /// Creates publisher with the given output type, that immediately terminates with
    /// the specified failure.
    ///
    /// Use this initializer to create a `Fail` publisher that can work with
    /// subscribers or publishers that expect a given output type.
    ///
    /// - Parameters:
    ///   - outputType: The output type exposed by this publisher.
    ///   - failure: The failure to send when terminating the publisher.
    // 在泛型的系统里面, 使用类型参数进行编译绑定, 是非常常见的功能.
    // 仅仅是进行类型绑定, 在类里面, 其实是完全没有用到该类型的功能的.
    public init(outputType: Output.Type, failure: Failure) {
        self.error = failure
    }
    
    /// The failure to send when terminating the publisher.
    public let error: Failure
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        subscriber.receive(subscription: Subscriptions.empty)
        subscriber.receive(completion: .failure(error))
    }
}

extension Fail: Equatable where Failure: Equatable {}
