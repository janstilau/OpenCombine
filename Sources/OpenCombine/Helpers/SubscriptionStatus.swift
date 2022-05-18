//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

// 这是一个通用的设计.
internal enum SubscriptionStatus {
    case awaitingSubscription
    case subscribed(Subscription)
    case pendingTerminal(Subscription)
    case terminal
}

extension SubscriptionStatus {
    internal var isAwaitingSubscription: Bool {
        switch self {
        case .awaitingSubscription:
            return true
        default:
            return false
        }
    }
    
    // 在枚举中, 定义属性进行关联类型的读取, 是一个非常非常常规的操作.
    // 这种 get property 能够大大简化代码逻辑, 让代码更加清晰.
    // 基本思路就是, switch case 判断, 在对应的状态下, 返回抽取出来的数据. 不在对应的状态下, 返回 nil.
    internal var subscription: Subscription? {
        switch self {
        case .awaitingSubscription, .terminal:
            return nil
        case let .subscribed(subscription), let .pendingTerminal(subscription):
            return subscription
        }
    }
}
