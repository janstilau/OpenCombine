//
//  DelegateProxyType.swift
//  CombineCocoa
//
//  Created by Joan Disho on 25/09/2019.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import Foundation

private var associatedKey = "delegateProxy"

public protocol DelegateProxyType {
    associatedtype Object
    
    func setDelegate(to object: Object)
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)

// 这里限制了 Self 的类型. 所以下面的 Init 方法, 其实是调用 DelegateProxy 的.
// 这是一个带有副作用的方法, 目的就在于, 使得 Object 上附加一个 Publisher 的管理器.
// 相比 Rx, 其实是有点问题的. 因为没有去管理, ForwardDelegate 相关的逻辑.
public extension DelegateProxyType where Self: DelegateProxy {
    static func createDelegateProxy(for object: Object) -> Self {
        // 先是上锁, objc_sync_enter 就是 @synchronize 的含义.
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
        
        // 使用, 关联对象, 进行 Object 的每个自己类的实际代理对象, 进行了挂钩. 
        let delegateProxy: Self
        if let associatedObject = objc_getAssociatedObject(object, &associatedKey) as? Self {
            delegateProxy = associatedObject
        } else {
            delegateProxy = .init()
            objc_setAssociatedObject(object, &associatedKey, delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
        delegateProxy.setDelegate(to: object)
        return delegateProxy
    }
}
#endif
