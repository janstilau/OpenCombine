import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

import OpenCombine

extension URLSession {
    
    public struct OCombine {
        
        public let session: URLSession
        
        public init(_ session: URLSession) {
            self.session = session
        }
        
        public struct DataTaskPublisher: Publisher {
            
            public typealias Output = (data: Data, response: URLResponse)
            
            public typealias Failure = URLError
            
            public let request: URLRequest
            
            public let session: URLSession
            
            // 惯例, Publisher 就是为了收集信息的
            public init(request: URLRequest, session: URLSession) {
                self.request = request
                self.session = session
            }
            
            // 真正的触发, 是在 receive 到 downstream 的 attach 请求的时候.
            public func receive<Downstream: Subscriber>(subscriber: Downstream)
            where Downstream.Failure == Failure, Downstream.Input == Output
            {
                let subscription = Inner(parent: self, downstream: subscriber)
                subscriber.receive(subscription: subscription)
            }
        }
        
        /// Returns a publisher that wraps a URL session data task for a given URL.
        ///
        /// The publisher publishes data when the task completes, or terminates if
        /// the task fails with an error.
        ///
        /// - Parameter url: The URL for which to create a data task.
        /// - Returns: A publisher that wraps a data task for the URL.
        public func dataTaskPublisher(for url: URL) -> DataTaskPublisher {
            return dataTaskPublisher(for: URLRequest(url: url))
        }
        
        /// Returns a publisher that wraps a URL session data task for a given
        /// URL request.
        ///
        /// The publisher publishes data when the task completes, or terminates if
        /// the task fails with an error.
        ///
        /// - Parameter request: The URL request for which to create a data task.
        /// - Returns: A publisher that wraps a data task for the URL request.
        public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
            return .init(request: request, session: session)
        }
    }
    
#if !canImport(Combine)
    public typealias DataTaskPublisher = OCombine.DataTaskPublisher
#endif
}

extension URLSession {
    
    /*
     原理和各种 yd, rx 扩展一模一样, 使用一个新的 NameSpace 来完成各种动作.
     */
    /// A namespace for disambiguation when both OpenCombine and Foundation are imported.
    ///
    /// Foundation extends `URLSession` with new methods and nested types.
    /// If you import both OpenCombine and Foundation, you will not be able
    /// to write `URLSession.shared.dataTaskPublisher(for: url)`,
    /// because Swift is unable to understand which `dataTaskPublisher` method
    /// you're referring to — the one declared in Foundation or in OpenCombine.
    ///
    /// So you have to write `URLSession.shared.ocombine.dataTaskPublisher(for: url)`.
    ///
    /// This bug is tracked [here](https://bugs.swift.org/browse/SR-11183).
    ///
    /// You can omit this whenever Combine is not available (e. g. on Linux).
    public var ocombine: OCombine { return .init(self) }
    
#if !canImport(Combine)
    /// Returns a publisher that wraps a URL session data task for a given URL.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task
    /// fails with an error.
    ///
    /// - Parameter url: The URL for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL.
    public func dataTaskPublisher(for url: URL) -> DataTaskPublisher {
        return ocombine.dataTaskPublisher(for: url)
    }
    
    /// Returns a publisher that wraps a URL session data task for a given URL request.
    ///
    /// The publisher publishes data when the task completes, or terminates if the task
    /// fails with an error.
    ///
    /// - Parameter request: The URL request for which to create a data task.
    /// - Returns: A publisher that wraps a data task for the URL request.
    public func dataTaskPublisher(for request: URLRequest) -> DataTaskPublisher {
        return ocombine.dataTaskPublisher(for: request)
    }
#endif
}

extension URLSession.OCombine.DataTaskPublisher {
    // DataTask 的相应链条的头结点. 所以是 Subscription.
    // 头结点, 不会 attach 到节点的后方, 所以不是 Subscriber.
    private class Inner<Downstream: Subscriber>
    : Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == (data: Data, response: URLResponse),
          Downstream.Failure == URLError
    {
        private let lock = UnfairLock.allocate()
        
        private var parent: URLSession.OCombine.DataTaskPublisher?
        
        private var downstream: Downstream?
        
        private var demand = Subscribers.Demand.none
        
        private var task: URLSessionDataTask?
        
        fileprivate init(parent: URLSession.OCombine.DataTaskPublisher,
                         downstream: Downstream) {
            self.parent = parent
            self.downstream = downstream
        }
        
        deinit {
            lock.deallocate()
        }
        
        // 当, 下游节点进行 demand 的 request 的时候, 进行真正的网络请求的发送.
        // 这是尊重 Combine 的 Pull 原型的做法.
        func request(_ demand: Subscribers.Demand) {
            demand.assertNonZero()
            lock.lock()
            guard let parent = self.parent else {
                lock.unlock()
                return
            }
            /*
             当下游请求 Demand 的时候, 使用原始的闭包的形式进行数据的采集, 在闭包中进行自身的信号发送.
             */
            if self.task == nil {
                task = parent.session.dataTask(with: parent.request,
                                               completionHandler: handleResponse)
            }
            self.demand += demand
            let task = self.task
            lock.unlock()
            task?.resume()
        }
        
        private func handleResponse(data: Data?, response: URLResponse?, error: Error?) {
            lock.lock()
            // 在 DataTask 的回调里面, 根据收到的信息, 向后方节点发送对应的数据.
            guard demand > 0,
                    parent != nil,
                    let downstream = self.downstream else {
                lock.unlock()
                return
            }
            // 当, 收到响应之后, 立马进行了资源的释放 .
            lockedTerminate()
            lock.unlock()
            
            // 根据结构, 发送相关的信号.
            switch (data, response, error) {
            case let (data, response?, nil):
                _ = downstream.receive((data ?? Data(), response))
                downstream.receive(completion: .finished)
            case let (_, _, error as URLError):
                downstream.receive(completion: .failure(error))
            default:
                downstream.receive(completion: .failure(URLError(.unknown)))
            }
        }
        
        // 当, DataTask.Sink 之后, 一定要保存好返回的 Subscription 对象.
        // 不然, 该对象 deinit 的时候, 调用 cancel, 也会导致上游节点的 cancel 行为.
        func cancel() {
            lock.lock()
            guard parent != nil else {
                lock.unlock()
                return
            }
            let task = self.task
            // 资源释放
            lockedTerminate()
            lock.unlock()
            // 真正网络请求的取消.
            task?.cancel()
        }
        
        private func lockedTerminate() {
            parent = nil
            downstream = nil
            demand = .none
            task = nil
        }
        
        var description: String { return "DataTaskPublisher" }
        
        var customMirror: Mirror {
            lock.lock()
            defer { lock.unlock() }
            let children: [Mirror.Child] = [
                ("task", task as Any),
                ("downstream", downstream as Any),
                ("parent", parent as Any),
                ("demand", demand)
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
