//
//  Subscriptions.swift
//
//
//  Created by Sergej Jaskiewicz on 26.06.2019.
//

/// A namespace for symbols related to subscriptions.
public enum Subscriptions {}

extension Subscriptions {
    
    /// Returns the “empty” subscription.
    ///
    /// Use the empty subscription when you need a `Subscription` that ignores requests
    /// and cancellation.
    // 所有的, 都是返回一个抽象数据类型. 实际的数据类型, 是一个内部的隐藏类. 
    public static let empty: Subscription = _EmptySubscription.singleton
}

// 类似于, Rx 里面的 FakeCancel 的概念.
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
