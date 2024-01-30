//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

// 使用 Enum 当做盒子来进行使用.
internal enum SubscriptionStatus {
    case awaitingSubscription
    case subscribed(Subscription)
    case pendingTerminal(Subscription)
    case terminal
}

// 对于 Enum 来说, 使用计算属性, 将值进行提取, 是一个非常通用的设计.
extension SubscriptionStatus {
    internal var isAwaitingSubscription: Bool {
        switch self {
        case .awaitingSubscription:
            return true
        default:
            return false
        }
    }

    internal var subscription: Subscription? {
        switch self {
        case .awaitingSubscription, .terminal:
            return nil
        case let .subscribed(subscription), let .pendingTerminal(subscription):
            return subscription
        }
    }
}
