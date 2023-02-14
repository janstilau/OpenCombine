// 里面存储的是 ConduitBase, 所以给了业务进行自定义的接口.
// 这是一个 Enum. 是一个把 Enum 当做盒子使用的示例. 
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
            // 如果, 之前没有值, 做状态改变到 一个值.
            self = .single(conduit)
        case .single(conduit):
            // ConduitBase 是一个引用类型, 所以是引用判等
            // 这里和下面 single(let existingConduit) 不一样, 这个 case 是判断,
            // conduit 和传进来的是一个值.
            // 有点不太好理解.
            break // This element already exists.
        case .single(let existingConduit):
            // Single 变 Set. Enum 的状态变化, 会有取值,赋值的操作.
            self = .many([existingConduit, conduit])
        case .many(var set):
            set.insert(conduit)
            self = .many(set)
        }
    }
    
    // Enum 应该提供了更加编译的方法, 给外界使用. 让外界在进行一次提取实在是类太难用了.
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
            // 这里 fallthrough 了
        case .empty, .single:
            break
        case .many(var set):
            set.remove(conduit)
            self = .many(set)
        }
    }
}
