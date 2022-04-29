//
//  Utils.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

// 这个 Take 的抽象, 其实可以当做一个通用的抽象来进行记忆.
// 那就是, 把当前的值进行返回, 然后让自已的当前值, 到一个该类型的默认初始化的状态
// 例如, 空数值, 空字典, optional nil.
extension Optional {
    internal mutating func take() -> Optional {
        let taken = self
        self = nil
        return taken
    }
}
