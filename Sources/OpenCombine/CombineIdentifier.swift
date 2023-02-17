#if canImport(COpenCombineHelpers)
import COpenCombineHelpers
#endif

#if WASI
private var __identifier: UInt64 = 0

internal func __nextCombineIdentifier() -> UInt64 {
    defer { __identifier += 1 }
    return __identifier
}
#endif // WASI

/// A unique identifier for identifying publisher streams.
///
/// To conform to `CustomCombineIdentifierConvertible` in a
/// `Subscription` or `Subject` that you implement as a structure, create an instance of
/// `CombineIdentifier` as follows:
///
///     let combineIdentifier = CombineIdentifier()

/*
 如果使用一个 Int 来进行表示, 那么使用方每次初始化的时候, 会使用 getNextId() 这个方法进行获取.
 使用特殊的类型, CombineIdentifier 将 getNextId 这个实现封装到了内部, 这个特殊的类型, 也暴露出返回原始类型 Id 的方法, 是一种更加优秀的设计理念. 
 */
public struct CombineIdentifier: Hashable, CustomStringConvertible {
    
    private let rawValue: UInt64
    
    /// Creates a unique Combine identifier.
    public init() {
        // __nextCombineIdentifier, 就是一个全局量的修改.
        rawValue = __nextCombineIdentifier()
    }
    
    /// Creates a Combine identifier, using the bit pattern of the provided object.
    // 使用 引用对象初始化, 直接使用引用对象的地址进行 rawValue 的赋值. 
    public init(_ obj: AnyObject) {
        rawValue = UInt64(UInt(bitPattern: ObjectIdentifier(obj)))
    }
    
    public var description: String {
        return "0x\(String(rawValue, radix: 16))"
    }
}
