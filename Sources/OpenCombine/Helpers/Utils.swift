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
extension HasDefaultValue {
    internal mutating func take() -> Self {
        let taken = self
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
