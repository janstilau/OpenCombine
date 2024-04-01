
/// A namespace for types that serve as publishers.
///
/// The various operators defined as extensions on `Publisher` implement their
/// functionality as classes or structures that extend this enumeration.
/// For example, the `contains(_:)` operator returns a `Publishers.Contains` instance.
///

/// 用于作为发布者的类型的命名空间。
///
/// 在 Publisher 上定义的各种操作符，其功能实现为扩展此枚举的类或结构。
/// 例如，contains(_:) 操作符返回一个 Publishers.Contains 实例。

// 所有的 Operator 是在 Publishers 这样的一个作用域里面进行的定义. 
public enum Publishers {}
