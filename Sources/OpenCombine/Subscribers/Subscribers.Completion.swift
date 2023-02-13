#if canImport(_Concurrency) && compiler(>=5.5)
import _Concurrency
#endif

extension Subscribers {
    /// A signal that a publisher doesn’t produce additional elements, either due to
    /// normal completion or an error.
    
    // 和 Rx 不同的是, Event 没有抽象出来, 而是使用了 Completion 来封装结束数据.
    // 这里的 Failure, 不仅仅是 Error, 它是一个泛型类型是锁了类型的. 在使用的时候, 要写出具体的数据类型出来.
    // 这也就是 Swift 中, 泛型的类型绑定的作用.
    public enum Completion<Failure: Error> {
        
        /// The publisher finished normally.
        case finished
        
        /// The publisher stopped publishing due to the indicated error.
        case failure(Failure)
    }
}

extension Subscribers.Completion: Equatable where Failure: Equatable {}

extension Subscribers.Completion: Hashable where Failure: Hashable {}

// 这里居然有着对于 Sendable 的支持.
#if canImport(_Concurrency) && compiler(>=5.5) || compiler(>=5.5.1)
extension Subscribers.Completion: Sendable {}
#endif

extension Subscribers.Completion {
    private enum CodingKeys: String, CodingKey {
        case success = "success"
        case error = "error"
    }
}

/*
 {
 success: true
 }
 {
 success: false
 error: {
    error 的具体信息.
 }
 }
 Enum 的序列化, 最好还是进行具体逻辑的编写.
 */

extension Subscribers.Completion: Encodable where Failure: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .finished:
            try container.encode(true, forKey: .success)
        case .failure(let error):
            try container.encode(false, forKey: .success)
            try container.encode(error, forKey: .error)
        }
    }
}

extension Subscribers.Completion: Decodable where Failure: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let success = try container.decode(Bool.self, forKey: .success)
        if success {
            self = .finished
        } else {
            let error = try container.decode(Failure.self, forKey: .error)
            self = .failure(error)
        }
    }
}

extension Subscribers.Completion {
    
    /// Erases the `Failure` type to `Swift.Error`. This function exists
    /// because in Swift user-defined generic types are always
    /// [invariant](https://en.wikipedia.org/wiki/Covariance_and_contravariance_(computer_science)).
    // 将, 自己的 Error 类型, 退化成为 Swfit.Error
    // 从逻辑上看, 数据没有任何的变化, 但是返回值的类型, 标志着泛型类型的具体信息消失了. 后续的节点, 使用的是 opaque 的 Error 了.
    // public protocol Error : Sendable { } 从 Swfit 的定义来看, Error 就是一个无任何类型信息的抽象类型.
    internal func eraseError() -> Subscribers.Completion<Error> {
        switch self {
        case .finished:
            return .finished
            // 在这里, 将 error 的类型进行了抹除操作. 
        case .failure(let error):
            return .failure(error)
        }
    }
    
    internal var failure: Failure? {
        switch self {
        case .finished:
            return nil
        case .failure(let failure):
            return failure
        }
    }
}
