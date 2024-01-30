
/// A namespace for types that serve as publishers.
///
/// The various operators defined as extensions on `Publisher` implement their
/// functionality as classes or structures that extend this enumeration.
/// For example, the `contains(_:)` operator returns a `Publishers.Contains` instance.

// 所有的 Operator 是在 Publishers 这样的一个作用域里面进行的定义. 
public enum Publishers {}
