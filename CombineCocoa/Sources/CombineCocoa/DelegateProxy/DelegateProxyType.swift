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
public extension DelegateProxyType where Self: DelegateProxy {
    static func createDelegateProxy(for object: Object) -> Self {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        // 动态的, 给 Object 绑定一个 DelegateProxyType
        let delegateProxy: Self
        if let associatedObject = objc_getAssociatedObject(object, &associatedKey) as? Self {
            delegateProxy = associatedObject
        } else {
            delegateProxy = .init()
            objc_setAssociatedObject(object, &associatedKey, delegateProxy, .OBJC_ASSOCIATION_RETAIN)
        }
        // 这里实现的不好, 应该还是要保留原来的 Delegate 才对. 
        delegateProxy.setDelegate(to: object)

        return delegateProxy
    }
}
#endif
