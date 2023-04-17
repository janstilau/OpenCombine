extension Result {
    // 根据闭包返回值的类型, 来决定函数返回值的类型, 这是一种十分常见的编码技巧.
    // 这种 Try 的会丢失 Error 的类型信息. 
    internal func tryMap<NewSuccess>(
        _ transform: (Success) throws -> NewSuccess
    ) -> Result<NewSuccess, Error> {
        switch self {
        case .success(let success):
            // 将, 闭包里面的操作进行了封装, 外界只会得到 Result 类型的结果.
            do {
                return try .success(transform(success))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
    
    // 强制的返回一个 Success 类型的结果, 提供了 failure 状态下转化为 Success 的闭包.
    // 这个 Failure 是 Result 里面定义的类型. 
    internal func unwrapOr(_ handleError: (Failure) -> Success) -> Success {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            return handleError(error)
        }
    }
    
    // 强制的返回一个 Success 类型的结果, 不需要处理 error, 闭包直接返回一个默认值. 
    internal func unwrapOr(_ handleError: @autoclosure () -> Success) -> Success {
        return unwrapOr { _ in handleError() }
    }
}

extension Result where Failure == Never {
    internal var success: Success {
        switch self {
        case .success(let success):
            return success
        }
    }
}
