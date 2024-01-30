//
//  Result.swift
//  
//
//  Created by Sergej Jaskiewicz on 17.06.2019.
//

extension Result {

    internal func tryMap<NewSuccess>(
        _ transform: (Success) throws -> NewSuccess
    ) -> Result<NewSuccess, Error> {
        switch self {
        case .success(let success):
            do {
                return try .success(transform(success))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    // 将原本的 Result, 切换成为了 Success 的值.
    // 这在有默认值处理的场景非常实用.
    internal func unwrapOr(_ handleError: (Failure) -> Success) -> Success {
        switch self {
        case .success(let success):
            return success
        case .failure(let error):
            return handleError(error)
        }
    }

    // 这种 @autoclosure 都是没有入参的. 
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
