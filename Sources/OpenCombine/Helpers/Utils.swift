//
//  Utils.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

internal protocol HasDefaultValue {
    init()
}

// 将自己的值全部取出来, 然后自己赋值成为一个空状态.
// 这是一个比较好的尝试, 可以用到自己的项目里面. 
extension HasDefaultValue {
    internal mutating func take() -> Self {
        let taken = self
        /*
         在 OC 里面, 是没有办法进行 self 的赋值的.
         在 Swift 里面, self 的赋值是值的替换.
         */
        self = .init()
        return taken
    }
}

extension Array: HasDefaultValue {}

extension Dictionary: HasDefaultValue {}

extension Optional: HasDefaultValue {
    init() {
        self = nil
    }
}
