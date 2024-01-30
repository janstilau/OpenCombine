//
//  ConduitList.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.06.2020.
//

// 不太明白,
internal enum ConduitList<Output, Failure: Error> {
    case empty
    case single(ConduitBase<Output, Failure>)
    // 这里使用了 Set, 并且 ConduitBase 其实是一个引用类型.
    // 这样其实是可以避免了重复.
    case many(Set<ConduitBase<Output, Failure>>)
}

extension ConduitList: HasDefaultValue {
    init() {
        self = .empty
    }
}

extension ConduitList {
    internal mutating func insert(_ conduit: ConduitBase<Output, Failure>) {
        switch self {
        case .empty:
            self = .single(conduit)
        case .single(conduit): // 如果, single 并且
            break // This element already exists.
        case .single(let existingConduit):
            self = .many([existingConduit, conduit])
        case .many(var set):
            set.insert(conduit)
            self = .many(set)
        }
    }

    internal func forEach(
        _ body: (ConduitBase<Output, Failure>) throws -> Void
    ) rethrows {
        switch self {
        case .empty:
            break
        case .single(let conduit):
            try body(conduit)
        case .many(let set):
            try set.forEach(body)
        }
    }

    internal mutating func remove(_ conduit: ConduitBase<Output, Failure>) {
        switch self {
        case .single(conduit):
            self = .empty
        case .empty, .single:
            break
        case .many(var set):
            set.remove(conduit)
            self = .many(set)
        }
    }
}
