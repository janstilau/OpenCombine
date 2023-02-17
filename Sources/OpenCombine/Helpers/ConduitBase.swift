
// 这是一个抽象类, 主要是进行 API 的设计. 
internal class ConduitBase<Output, Failure: Error>: Subscription {
    
    internal init() {}
    
    // 向存储的下游节点, 提供数据.
    internal func offer(_ output: Output) {
        abstractMethod()
    }
    
    // 向存储的下游节点, 提供完成事件.
    internal func finish(completion: Subscribers.Completion<Failure>) {
        abstractMethod()
    }
    
    // 完成, Subscription 的要求, 处理下游节点的 Demand 管理要求.
    internal func request(_ demand: Subscribers.Demand) {
        abstractMethod()
    }
    
    // 完后, Subscription 的要求, 完成下游节点触发的 cancel 操作. 
    internal func cancel() {
        abstractMethod()
    }
}

extension ConduitBase: Equatable {
    internal static func == (lhs: ConduitBase<Output, Failure>,
                             rhs: ConduitBase<Output, Failure>) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }
}

extension ConduitBase: Hashable {
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
