
/// A publisher that immediately terminates with the specified error.
// 只会发出, 失败的事件.
public struct Fail<Output, Failure: Error>: Publisher {
    
    /// Creates a publisher that immediately terminates with the specified failure.
    ///
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
    public init(outputType: Output.Type, failure: Failure) {
        self.error = failure
    }
    
    /// The failure to send when terminating the publisher.
    public let error: Failure
    
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        // 还是会保留, 发送订阅这回事.
        // 然后立马就发送存储的失败了. 
        subscriber.receive(subscription: Subscriptions.empty)
        subscriber.receive(completion: .failure(error))
    }
}

extension Fail: Equatable where Failure: Equatable {}
