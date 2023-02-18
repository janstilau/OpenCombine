//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

// 这是一个通用的设计.
internal enum SubscriptionStatus {
    case awaitingSubscription
    // 这里使用 Subscription 整个 Protocol 来进行存储, 是怎么进行内存分配的呢. 
    case subscribed(Subscription)
    // 这个状态, 会在 schedule 参与的场景中使用. 
    case pendingTerminal(Subscription)
    case terminal
}

// 惯例实现, Enum 应该提供更好的属性来进行其中值的抽取.
// 本身状态就可以当做是值的一部分进行判断.
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
            // 可以通过这样的方式, 进行值的抽取. 只要是两个不同的状态, 可以使用同样的变量名抽取就可以了.
            // 模式匹配, 主要是位置的匹配. 
            return subscription
        }
    }
}
