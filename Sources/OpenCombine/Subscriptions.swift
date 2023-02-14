
/// A namespace for symbols related to subscriptions.

// 这种专门定义一个命名空间, 进行相关类型的封装是一个非常优秀的设计里面. 
public enum Subscriptions {}

extension Subscriptions {
    
    /// Returns the “empty” subscription.
    ///
    /// Use the empty subscription when you need a `Subscription` that ignores requests
    /// and cancellation.
    
    // 所有的, 都是返回一个抽象数据类型. 实际的数据类型, 是一个内部的隐藏类.
    // 当, 没有真正的生成一个 Sink 节点的时候, 向后方节点, 传递该值. 
    public static let empty: Subscription = _EmptySubscription.singleton
}

// 所有的, 都是一个空操作, 不会影响到整个响应链路的运转.
extension Subscriptions {
    private struct _EmptySubscription: Subscription,
                                       CustomStringConvertible,
                                       CustomReflectable,
                                       CustomPlaygroundDisplayConvertible {
        fileprivate static let singleton = _EmptySubscription()
        
        let combineIdentifier = CombineIdentifier()
        
        private init() {}
        
        func request(_ demand: Subscribers.Demand) {}
        
        func cancel() {}
        
        var description: String { return "Empty" }
        
        var customMirror: Mirror { return Mirror(self, children: EmptyCollection()) }
        
        var playgroundDescription: Any { return description }
    }
}
