// 直接发送错误.
/*
 Just, Fail 其实有着应用场景的.
 就是将已经通过其他方式获取到的值, 纳入到响应链路中.
 可能是 FlatMap 这种, 也可能是直接作为头结点.
 
 这种场景其实挺多的. 当需要控制通路数据的时候, 也就是人工想要参与逻辑判断的时候, 这些根据确定值来发射信号的操作符就在这里使用.
 */
/// A publisher that immediately terminates with the specified error.
// 这里有 Output, 所以使用的时候, 该填写的信息还要写.
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
    // 使用这种方式, 就不需要专门写类型参数了. 而实际上, 参数是无用的, 仅仅是为了进行类型绑定. 
    public init(outputType: Output.Type, failure: Failure) {
        self.error = failure
    }
    
    /// The failure to send when terminating the publisher.
    public let error: Failure
    
    // 因为, Completion 事件, 是不受 Demand 控制的. 所以, 在 attach 后方节点的时候, 直接发送了 error 事件.
    public func receive<Downstream: Subscriber>(subscriber: Downstream)
    where Output == Downstream.Input, Failure == Downstream.Failure
    {
        // 整个 Combine 的通信, 是遵循一套流程的.
        // Publisher 创建 Subscription 作为整个相应链路的真正节点, 是必须的.
        // 所以这里还是创建了 subscription. 理论上, 应该由这个 Subscription 将后续信号发送给 downstream, 这里直接 Publisher 进行了发送. 
        subscriber.receive(subscription: Subscriptions.empty)
        subscriber.receive(completion: .failure(error))
    }
}

extension Fail: Equatable where Failure: Equatable {}
