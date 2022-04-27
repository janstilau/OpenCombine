//
//  Utils.swift
//
//
//  Created by Sergej Jaskiewicz on 28.08.2021.
//

internal protocol HasDefaultValue {
    init()
}

// Take 的意思是, 将这个类型里面的值全部取出, 然后将 Self 设置成为一个初始的空值状态. 
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
