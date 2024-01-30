/// A publisher that provides an explicit means of connecting and canceling publication.
///
/// Use a `ConnectablePublisher` when you need to perform additional configuration or
/// setup prior to producing any elements.
///
/// This publisher doesn’t produce any elements until you call its `connect()` method.
///
/// Use `makeConnectable()` to create a `ConnectablePublisher` from any publisher whose
/// failure type is `Never`.

/// 一个提供显式连接和取消发布的发布者。
///
/// 当需要在生成任何元素之前执行额外的配置或设置时，请使用 `ConnectablePublisher`。
///
/// 该发布者在调用其 `connect()` 方法之前不会产生任何元素。
///
/// 使用 `makeConnectable()` 从任何失败类型为 `Never` 的发布者创建一个 `ConnectablePublisher`。

/*
 // 创建一个普通的发布者
 let publisher = (1...3).publisher

 // 将普通发布者转换为 ConnectablePublisher
 let connectablePublisher = publisher.makeConnectable()

 // 订阅 ConnectablePublisher，但不会立即开始发布元素
 let cancellable = connectablePublisher.sink { value in
     print("Received value: \(value)")
 }

 // 连接 ConnectablePublisher，开始发布元素
 connectablePublisher.connect()
 */
public protocol ConnectablePublisher: Publisher {

    /// Connects to the publisher, allowing it to produce elements, and returns
    /// an instance with which to cancel publishing.
    ///
    /// - Returns: A `Cancellable` instance that you use to cancel publishing.
    func connect() -> Cancellable
}
