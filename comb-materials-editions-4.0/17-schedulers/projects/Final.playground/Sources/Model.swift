import SwiftUI
import Combine

/// A basic event we want to represent in the timeline view
/// We don't need to keep the value data around as we'll only
/// be interested in displaying the value index in the values sequence
public enum Event: Equatable, CustomDebugStringConvertible {
    case value
    case completion
    case failure
    
    public var debugDescription: String {
        switch self {
        case .value: return "value"
        case .completion: return "completion"
        case .failure: return "failure"
        }
    }
}
