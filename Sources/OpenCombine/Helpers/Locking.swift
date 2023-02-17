//
//  Locking.swift
//  
//
//  Created by Sergej Jaskiewicz on 11.06.2019.
//

#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

// 从这里看, deallocate 没有做任何的事情.
// 猜测可能会使用 C 风格的 API, 那么最后其实需要使用 deallocate 去做资源的回收的. 
#if WASI
internal struct __UnfairLock { // swiftlint:disable:this type_name
    internal static func allocate() -> UnfairLock { return .init() }
    internal func lock() {}
    internal func unlock() {}
    internal func assertOwner() {}
    internal func deallocate() {}
}

internal struct __UnfairRecursiveLock { // swiftlint:disable:this type_name
    internal static func allocate() -> UnfairRecursiveLock { return .init() }
    internal func lock() {}
    internal func unlock() {}
    internal func deallocate() {}
}
#endif // WASI

internal typealias UnfairLock = __UnfairLock
internal typealias UnfairRecursiveLock = __UnfairRecursiveLock
