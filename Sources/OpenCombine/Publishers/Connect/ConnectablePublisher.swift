/// A publisher that provides an explicit means of connecting and canceling publication.

// 这里说的很明白, 使用 ConnectablePublisher 目的就在于, 在真正的出发信号产生逻辑之前, 进行更多的配置.
// 现在来看, 最常用的更多的配置其实是进行多个下游节点的 sink.
//
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.

/// This publisher doesn’t produce any elements until you call its `connect()` method.

// 必须显示的调用 connect, 才会真正完成信号的开始生成.

/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.
public protocol ConnectablePublisher: Publisher {
    
    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    
    func connect() -> Cancellable
}

/*
 对于 ConnectablePublisher, 它能够正常的进行 receive subscriber, 还能够进行 connect.
 所以它内部其实要提供一种机制, 就是存储 subscriber, 这些 subscriber 的 receive, 并不会引起自身信号的真正开始产生.
 知道 connect 的时候, 才会引起开始产生信号数据.
 */

/*
 真正起到多路复用的, 其实是 MultiCast 这个类.
 这个类, 既完成了多路复用, 也实现了 connectable.
 多路复用实现原理是将下游, 都 attach 到 subject 上.
 connect 的原理是, 将 Subject attach 真正的 Upstream 上.
 
 MakeConnectable
 就是 Upstream 构建出一个 MultiCast 的过程.
 
 Autoconnect 面对的其实是一个 ConnectablePublisher 对象.
 他的主要作用是下游来临时, 主动的进行 connect 方法的调用. 在下游都进行 cancel 的时候, 主动进行 connect 返回的 canaelable 对象 cancel 方法的调用.
 一般来说, ConnectablePublisher 里面会有存储多个 subscriber 的机制. 
 */
