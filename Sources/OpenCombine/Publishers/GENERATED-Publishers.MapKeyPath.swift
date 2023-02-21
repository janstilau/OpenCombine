extension Publisher {
    /// Publishes the value of the key path.
    
    /// In the following example, the `map(_:)` operator uses the Swift
    /// key path syntax to access the `die` member
    /// of the `DiceRoll` structure published by the `Just` publisher.
    // KeyPath 这种方式, 具有很强的编译检查, 不太明白其中的原理.
    // 不过, 应该不是使用的 OC 的动态查找的机制.
    
    /// The downstream sink subscriber receives only
    /// the value of this `Int`,
    /// not the entire `DiceRoll`.
    ///
    ///     struct DiceRoll {
    ///         let die: Int
    ///     }
    ///
    ///     cancellable = Just(DiceRoll(die: Int.random(in: 1...6)))
    ///         .map(\.die)
    ///         .sink {
    ///             print ("Rolled: \($0)")
    ///         }
    ///     // Prints "Rolled: 6 (or some other random value).
    
    /// - Parameters:
    ///    - keyPath: The key path of a property on `Output`.
    /// - Returns: A publisher that publishes the value of the key path.
    // 在方法的内部, 仅仅是需要一个 KeyPath 就可以. KeyPath 的类型参数, 左边是 Instance 的类型, 右边是 Instance 的属性的类型.
    public func map<Result>(
        _ keyPath: KeyPath<Output, Result>
    ) -> Publishers.MapKeyPath<Self, Result> {
        // 惯例实现, 作为 Publisher, 是进行信息的收集工作.
        return .init(upstream: self, keyPath: keyPath
        )
    }
    
    // 使用函数重载这种编译技术, 使得可以进行多分的 KeyPath 参数.
    // 具体的生成的类型, 是使用了函数的参数推导的技术.
    /// Publishes the values of two key paths as a tuple.
    ///
    /// In the following example, the `map(_:_:)` operator uses the Swift
    /// key path syntax to access the `die1` and `die2` members
    /// of the `DiceRoll` structure published by the `Just` publisher.
    ///
    /// The downstream sink subscriber receives only
    /// these two values (as an `(Int, Int)` tuple),
    /// not the entire `DiceRoll`.
    ///
    ///     struct DiceRoll {
    ///         let die1: Int
    ///         let die2: Int
    ///     }
    ///
    ///     cancellable = Just(DiceRoll(die1: Int.random(in: 1...6),
    ///                                 die2: Int.random(in: 1...6)))
    ///         .map(\.die1, \.die2)
    ///         .sink { values in
    ///             print("""
    ///             Rolled: \(values.0), \(values.1) \
    ///             (total \(values.0 + values.1))
    ///             """)
    ///         }
    ///     // Prints "Rolled: 5, 3 (total: 8)" (or other random values).
    ///
    /// - Parameters:
    ///    - keyPath0: The key path of a property on `Output`.
    ///    - keyPath1: The key path of another property on `Output`.
    /// - Returns: A publisher that publishes the values of two key paths as a tuple.
    
    // Result0, Result1 的具体类型, 是使用 map 函数的时候, 根据传递过来的 \.属性名 来确定的
    public func map<Result0, Result1>(
        _ keyPath0: KeyPath<Output, Result0>,
        _ keyPath1: KeyPath<Output, Result1>
    ) -> Publishers.MapKeyPath2<Self, Result0, Result1> {
        return .init(
            upstream: self,
            keyPath0: keyPath0,
            keyPath1: keyPath1
        )
    }
    /// Publishes the values of three key paths as a tuple.
    ///
    /// In the following example, the `map(_:_:_:)` operator uses the Swift
    /// key path syntax to access the `die1`, `die2`, and `die3` members
    /// of the `DiceRoll` structure published by the `Just` publisher.
    ///
    /// The downstream sink subscriber receives only
    /// these three values (as an `(Int, Int, Int)` tuple),
    /// not the entire `DiceRoll`.
    ///
    ///     struct DiceRoll {
    ///         let die1: Int
    ///         let die2: Int
    ///         let die3: Int
    ///     }
    ///
    ///     cancellable = Just(DiceRoll(die1: Int.random(in: 1...6),
    ///                                 die2: Int.random(in: 1...6),
    ///                                 die3: Int.random(in: 1...6)))
    ///         .map(\.die1, \.die2, \.die3)
    ///         .sink { values in
    ///             print("""
    ///             Rolled: \(values.0), \(values.1), \(values.2) \
    ///             (total \(values.0 + values.1 + values.2))
    ///             """)
    ///         }
    ///     // Prints "Rolled: 2, 4, 3 (total: 9)" (or other random values).
    ///
    /// - Parameters:
    ///    - keyPath0: The key path of a property on `Output`.
    ///    - keyPath1: The key path of a second property on `Output`.
    ///    - keyPath2: The key path of a third property on `Output`.
    /// - Returns: A publisher that publishes the values of three key paths as a tuple.
    public func map<Result0, Result1, Result2>(
        _ keyPath0: KeyPath<Output, Result0>,
        _ keyPath1: KeyPath<Output, Result1>,
        _ keyPath2: KeyPath<Output, Result2>
    ) -> Publishers.MapKeyPath3<Self, Result0, Result1, Result2> {
        return .init(
            upstream: self,
            keyPath0: keyPath0,
            keyPath1: keyPath1,
            keyPath2: keyPath2
        )
    }
}

extension Publishers {
    
    /// A publisher that publishes the value of a key path.
    public struct MapKeyPath<Upstream: Publisher, Output>: Publisher {
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The key path of a property to publish.
        // 这里写的很清楚, KeyPath 的 Instance 类型, 是 Upstream.Output 的类型,
        public let keyPath: KeyPath<Upstream.Output, Output>

        // 惯例实现, 在 Publisher 里面, 构造真正的节点, 然后构造到对应的响应链条中.
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, parent: self))
        }
    }
    
    /// A publisher that publishes the values of two key paths as a tuple.
    // MapKeyPath2 来说, 就是有这个两个 TypeParameters.
    public struct MapKeyPath2<Upstream: Publisher, Output0, Output1>: Publisher {
        
        public typealias Output = (Output0, Output1)
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The key path of a property to publish.
        public let keyPath0: KeyPath<Upstream.Output, Output0>
        
        /// The key path of a second property to publish.
        public let keyPath1: KeyPath<Upstream.Output, Output1>
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
        {
            // 数据还是存在了 Puhlisher 里面, 其实可以复制过去的. 这都是一些值语义的数据.
            upstream.subscribe(Inner(downstream: subscriber, parent: self))
        }
    }
    
    /// A publisher that publishes the values of three key paths as a tuple.
    public struct MapKeyPath3<Upstream: Publisher, Output0, Output1, Output2>: Publisher {
        
        public typealias Output = (Output0, Output1, Output2)
        
        public typealias Failure = Upstream.Failure
        
        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream
        
        /// The key path of a property to publish.
        public let keyPath0: KeyPath<Upstream.Output, Output0>
        
        /// The key path of a second property to publish.
        public let keyPath1: KeyPath<Upstream.Output, Output1>
        
        /// The key path of a third property to publish.
        public let keyPath2: KeyPath<Upstream.Output, Output2>
        
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Output == Downstream.Input, Failure == Downstream.Failure
        {
            upstream.subscribe(Inner(downstream: subscriber, parent: self))
        }
    }
}

extension Publishers.MapKeyPath {
    
    // 没有成为 Subscription, 直接将上游节点的Subscription, 传递给了下游节点.
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let keyPath: KeyPath<Input, Output>
        
        let combineIdentifier = CombineIdentifier()
        
        // 节点的初始化, 就是进行值的赋值操作.
        //
        fileprivate init(
            downstream: Downstream,
            parent: Publishers.MapKeyPath<Upstream, Output>
        ) {
            self.downstream = downstream
            self.keyPath = parent.keyPath
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        // 当, 收到上游数据之后, 是使用了 KeyPath 进行了提取, 然后给到后续的节点.
        func receive(_ input: Input) -> Subscribers.Demand {
            let output = (
                // 使用 key 的方式, 对于新进来的值进行取值.
                // 最终是使用 tuple 的方式, 对值进行了组合. 
                input[keyPath: keyPath]
            )
            return downstream.receive(output)
        }
        
        // 直接, 将完成事件, 发送给了后续节点.
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
        
        var description: String { return "ValueForKey" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("keyPath", keyPath),
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}

extension Publishers.MapKeyPath2 {
    
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let keyPath0: KeyPath<Input, Output0>
        
        private let keyPath1: KeyPath<Input, Output1>
        
        let combineIdentifier = CombineIdentifier()
        
        fileprivate init(
            downstream: Downstream,
            parent: Publishers.MapKeyPath2<Upstream, Output0, Output1>
        ) {
            self.downstream = downstream
            self.keyPath0 = parent.keyPath0
            self.keyPath1 = parent.keyPath1
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            // 使用, KeyPath 这种技术, 对于上游节点的数据, 进行了提取.
            let output = (
                input[keyPath: keyPath0],
                input[keyPath: keyPath1]
            )
            return downstream.receive(output)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
        
        var description: String { return "ValueForKeys" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("keyPath0", keyPath0),
                ("keyPath1", keyPath1),
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}

extension Publishers.MapKeyPath3 {
    
    private struct Inner<Downstream: Subscriber>
    : Subscriber,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Output, Downstream.Failure == Upstream.Failure
    {
        typealias Input = Upstream.Output
        
        typealias Failure = Upstream.Failure
        
        private let downstream: Downstream
        
        private let keyPath0: KeyPath<Input, Output0>
        
        private let keyPath1: KeyPath<Input, Output1>
        
        private let keyPath2: KeyPath<Input, Output2>
        
        let combineIdentifier = CombineIdentifier()
        
        fileprivate init(
            downstream: Downstream,
            parent: Publishers.MapKeyPath3<Upstream, Output0, Output1, Output2>
        ) {
            self.downstream = downstream
            self.keyPath0 = parent.keyPath0
            self.keyPath1 = parent.keyPath1
            self.keyPath2 = parent.keyPath2
        }
        
        func receive(subscription: Subscription) {
            downstream.receive(subscription: subscription)
        }
        
        func receive(_ input: Input) -> Subscribers.Demand {
            // 使用, KeyPath 这种技术, 对于上游的数据, 进行了提取. 
            let output = (
                input[keyPath: keyPath0],
                input[keyPath: keyPath1],
                input[keyPath: keyPath2]
            )
            return downstream.receive(output)
        }
        
        func receive(completion: Subscribers.Completion<Failure>) {
            downstream.receive(completion: completion)
        }
        
        var description: String { return "ValueForKeys" }
        
        var customMirror: Mirror {
            let children: [Mirror.Child] = [
                ("keyPath0", keyPath0),
                ("keyPath1", keyPath1),
                ("keyPath2", keyPath2),
            ]
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
    }
}
