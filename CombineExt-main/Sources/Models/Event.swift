
#if canImport(Combine)
/// Represents a Combine Event
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public enum Event<Output, Failure: Swift.Error> {
    case value(Output)
    case failure(Failure)
    case finished
}

// MARK: - Equatable Conformance
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Event: Equatable where Output: Equatable, Failure: Equatable {
    static public func == (lhs: Self, rhs: Self) -> Bool {
        // 经典的比较的方式, 在 case 中, 不适用嵌套.
        switch (lhs, rhs) {
        case (.finished, .finished):
            return true
        case let (.failure(err1), .failure(err2)):
            return err1 == err2
        case let (.value(val1), .value(val2)):
            return val1 == val2
        default:
            return false
        }
    }
}

// MARK: - Friendly Output
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Event: CustomStringConvertible {
    public var description: String {
        switch self {
        case .value(let val):
            return "value(\(val))"
        case .failure(let err):
            return "failure(\(err))"
        case .finished:
            return "finished"
        }
    }
}

// MARK: - Event Convertible

//
/// A protocol representing `Event` convertible types
@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public protocol EventConvertible {
    associatedtype Output
    associatedtype Failure: Swift.Error
    
    var event: Event<Output, Failure> { get }
}

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Event: EventConvertible {
    public var event: Event<Output, Failure> { self }
}
#endif
