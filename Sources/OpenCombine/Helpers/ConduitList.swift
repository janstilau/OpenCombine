//
//  ConduitList.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.06.2020.
//

/*
 不太明白, 这种 none, single, many 的设计意图是什么. 好多地方看到了这样类似的概念了.
 */
internal enum ConduitList<Output, Failure: Error> {
    case empty
    case single(ConduitBase<Output, Failure>)
    case many(Set<ConduitBase<Output, Failure>>)
}

// take 方法, 返回当前数据的所有数据, 然后将当前数据重置为 Init 的状态.
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
        case .single(conduit):
            // 这里和下面不一样, 这个 case 是, conduit 和传进来的是一个值.
            // 有点不太好理解.
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
