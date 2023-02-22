//
//  SubscriptionStatus.swift
//  
//
//  Created by Sergej Jaskiewicz on 21.09.2019.
//

// 这个 注册状态的管理, 是一个通过的设计.
internal enum SubscriptionStatus {
    // 这个状态主要用来做 Check 了, 当上游发送 Subscription 过来的时候, 要保证这个节点在 Awaiting 状态. 然后才能继续后续逻辑.
    case awaitingSubscription
    // 完成上游注册的状态, 在这个状态里面, 进行上游节点的引用, 完成了 Chain SelfRetain 的生命周期的保持.
    case subscribed(Subscription)
    // 只会出现在 shecduler 参与业务的场景里面
    case pendingTerminal(Subscription)
    // 终止.
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
