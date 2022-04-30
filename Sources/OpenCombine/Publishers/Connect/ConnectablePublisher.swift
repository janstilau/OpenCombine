
/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.
///
/// This publisher doesn’t produce any elements until you call its `connect()` method.

// 由, 使用者来控制, 是否进行信号的传输.

/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.

//
public protocol ConnectablePublisher: Publisher {
    
    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    
    // ConnectablePublisher 的 Publisher, 都会有一个盒子. 所有的 Subscribe(subscriber 方法, 都是将后续的节点, 装到那个盒子里面.
    // 上游的节点, 数据到达的时候, ConnectablePublisher 应该将数据分发到自己的盒子中的下游节点中.
    // 下游节点的各种 Demand 管理, 也应该保存在盒子里面. 当 Demand 到达了 Max 的时候, 不进行分发操作.
    // 当, 调用到 Connect 的时候, 才真正将自己, attach 到上游节点中. 
    func connect() -> Cancellable
}
