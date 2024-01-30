//
//  ConduitBase.swift
//  
//
//  Created by Sergej Jaskiewicz on 25.06.2020.
//

internal class ConduitBase<Output, Failure: Error>: Subscription {

    internal init() {}

    // 承接上游的数据.
    internal func offer(_ output: Output) {
        abstractMethod()
    }

    // 承接上游的完成事件.
    internal func finish(completion: Subscribers.Completion<Failure>) {
        abstractMethod()
    }

    // 承接下游的拉取
    internal func request(_ demand: Subscribers.Demand) {
        abstractMethod()
    }
    
    // 承接下游的取消
    internal func cancel() {
        abstractMethod()
    }
}

// ConduitBase 的存在主要意义, 是完成了唯一性的校验.
// 也就是, 所以它其实主要是为了适配 Set 这个容器.
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
