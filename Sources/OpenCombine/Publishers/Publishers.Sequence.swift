//
//  Publishers.Sequence.swift
//  
//
//  Created by Sergej Jaskiewicz on 19.06.2019.
//

extension Publishers {
    
    /// A publisher that publishes a given sequence of elements.
    ///
    /// When the publisher exhausts the elements in the sequence, the next request
    /// causes the publisher to finish.
    
    // Combine 里面, 信号的发射, 不仅仅和 Publisher 有关, 也和 Subscriber 的 Request 有关.
    // 如果, Subscriber 不在没有 Request 的 Demand, 那么其实 Publisher 是应该把自己产生的数据, 发布给后方节点的.
    public struct Sequence<Elements: Swift.Sequence, Failure: Error>: Publisher {
        public typealias Output = Elements.Element
        /// The sequence of elements to publish.
        // 存储, 传递过来的序列. 这是泛型类型, 所以会有类型的绑定.
        public let sequence: Elements
        
        /// Creates a publisher for a sequence of elements.
        public init(sequence: Elements) {
            self.sequence = sequence
        }
        
        /*
         Combine 的 Publisher 有着非常明显的处理流程.
         生成真正在响应链条里面存在的节点, 在节点里面, 存储了 Next 的 Subscriber
         将节点, 作为 subscription 传递给后续节点. 后续节点里面, 做对于 subscription 的记录.
         在 Subscriber 里面, 对传递过来的 subscription 调用 Request Demand. 进行真正的信号生成的触发.
         
         Producer 生成节点, 构建响应者链条. 真正在联调里面, 发挥作用的, 是各个节点类型.
         这在 Combine 以及 RxSwfit 里面, 是同样的一个思路.
         */
        public func receive<Downstream: Subscriber>(subscriber: Downstream)
        where Failure == Downstream.Failure, Elements.Element == Downstream.Input {
            let inner = Inner(downstream: subscriber, sequence: sequence)
            if inner.isExhausted {
                subscriber.receive(subscription: Subscriptions.empty)
                subscriber.receive(completion: .finished)
                inner.cancel()
            } else {
                subscriber.receive(subscription: inner)
            }
        }
    }
}

extension Publishers.Sequence {
    
    // Publishers.Sequence 的响应链条节点.
    private final class Inner<Downstream: Subscriber, Elements: Sequence, Failure>
    : Subscription,
      CustomStringConvertible,
      CustomReflectable,
      CustomPlaygroundDisplayConvertible
    where Downstream.Input == Elements.Element, Downstream.Failure == Failure {
        
        typealias Iterator = Elements.Iterator
        typealias Element = Elements.Element
        
        private var sequence: Elements? // Producer 里面, 记录的序列数据, 被原封不动的搬移到生成的 Node 中
        private var downstream: Downstream? // Producer 中, 接收到的 Subscriber 数据, 被原封不动的, 搬移到生成的 Node 中.
        private var iterator: Iterator
        private var next: Element?
        private var pendingDemand = Subscribers.Demand.none // 记录后续节点的需求. 对于
        private var recursion = false
        private var lock = UnfairLock.allocate()
        
        fileprivate init(downstream: Downstream, sequence: Elements) {
            self.sequence = sequence
            self.downstream = downstream
            self.iterator = sequence.makeIterator()
            next = iterator.next()
        }
        
        deinit {
            lock.deallocate()
        }
        
        fileprivate var isExhausted: Bool {
            return next == nil
        }
        
        var description: String {
            return sequence.map(String.init(describing:)) ?? "Sequence"
        }
        
        var customMirror: Mirror {
            let children =
            CollectionOfOne<Mirror.Child>(("sequence", sequence ?? [Element]()))
            return Mirror(self, children: children)
        }
        
        var playgroundDescription: Any { return description }
        
        /*
         和 Rx 比较.
         rx 是在 Subscribe 函数里面, 触发了对于信号的生产.
         Combine 是在 Request 里面, 触发了对于信号的生产.
         */
        func request(_ demand: Subscribers.Demand) {
            lock.lock()
            guard downstream != nil else {
                lock.unlock()
                return
            }
            pendingDemand += demand
            if recursion {
                lock.unlock()
                return
            }
            
            while let downstream = self.downstream, pendingDemand > 0 {
                // 一个循环体里面, 进行 Demand 的管理工作.
                if let current = self.next {
                    pendingDemand -= 1
                    
                    // 取值.
                    let next = iterator.next()
                    recursion = true
                    lock.unlock()
                    
                    // 然后让后方节点接受值. 拿到后方节点的 Demand 更新自己.
                    // 然后继续这个信号产生的循环.
                    let additionalDemand = downstream.receive(current)
                    lock.lock()
                    recursion = false
                    pendingDemand += additionalDemand
                    self.next = next
                }
                
                if next == nil {
                    // 在 Next 为 nil 的时候, 其实这里是调用了 cencel 方法了.
                    self.downstream = nil
                    self.sequence = nil
                    lock.unlock()
                    downstream.receive(completion: .finished)
                    return
                }
            }
            
            lock.unlock()
        }
        
        // cancel, 放弃了对于后续节点的引用.
        func cancel() {
            lock.lock()
            downstream = nil
            sequence = nil
            lock.unlock()
        }
    }
}

extension Publishers.Sequence: Equatable where Elements: Equatable {}

extension Publishers.Sequence where Failure == Never {
    
    public func min(
        by areInIncreasingOrder: (Elements.Element, Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.min(by: areInIncreasingOrder))
    }
    
    public func max(
        by areInIncreasingOrder: (Elements.Element, Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.max(by: areInIncreasingOrder))
    }
    
    public func first(
        where predicate: (Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.first(where: predicate))
    }
}

extension Publishers.Sequence {
    
    public func allSatisfy(
        _ predicate: (Elements.Element) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.allSatisfy(predicate))
    }
    
    public func tryAllSatisfy(
        _ predicate: (Elements.Element) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try sequence.allSatisfy(predicate) })
    }
    
    public func collect() -> Result<[Elements.Element], Failure>.OCombine.Publisher {
        return .init(Array(sequence))
    }
    
    public func compactMap<ElementOfResult>(
        _ transform: (Elements.Element) -> ElementOfResult?
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        return .init(sequence: sequence.compactMap(transform))
    }
    
    public func contains(
        where predicate: (Elements.Element) -> Bool
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.contains(where: predicate))
    }
    
    public func tryContains(
        where predicate: (Elements.Element) throws -> Bool
    ) -> Result<Bool, Error>.OCombine.Publisher {
        return .init(Result { try sequence.contains(where: predicate) })
    }
    
    public func drop(
        while predicate: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<DropWhileSequence<Elements>, Failure> {
        return .init(sequence: sequence.drop(while: predicate))
    }
    
    public func dropFirst(
        _ count: Int = 1
    ) -> Publishers.Sequence<DropFirstSequence<Elements>, Failure> {
        return .init(sequence: sequence.dropFirst(count))
    }
    
    public func filter(
        _ isIncluded: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: sequence.filter(isIncluded))
    }
    
    public func ignoreOutput() -> Empty<Elements.Element, Failure> {
        return .init()
    }
    
    public func map<ElementOfResult>(
        _ transform: (Elements.Element) -> ElementOfResult
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        return .init(sequence: sequence.map(transform))
    }
    
    public func prefix(
        _ maxLength: Int
    ) -> Publishers.Sequence<PrefixSequence<Elements>, Failure> {
        return .init(sequence: sequence.prefix(maxLength))
    }
    
    public func prefix(
        while predicate: (Elements.Element) -> Bool
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: sequence.prefix(while: predicate))
    }
    
    public func reduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult: @escaping (Accumulator, Elements.Element) -> Accumulator
    ) -> Result<Accumulator, Failure>.OCombine.Publisher {
        return .init(sequence.reduce(initialResult, nextPartialResult))
    }
    
    public func tryReduce<Accumulator>(
        _ initialResult: Accumulator,
        _ nextPartialResult:
        @escaping (Accumulator, Elements.Element) throws -> Accumulator
    ) -> Result<Accumulator, Error>.OCombine.Publisher {
        return .init(Result { try sequence.reduce(initialResult, nextPartialResult) })
    }
    
    public func replaceNil<ElementOfResult>(
        with output: ElementOfResult
    ) -> Publishers.Sequence<[Elements.Element], Failure>
    where Elements.Element == ElementOfResult?
    {
        return .init(sequence: sequence.map { $0 ?? output })
    }
    
    public func scan<ElementOfResult>(
        _ initialResult: ElementOfResult,
        _ nextPartialResult:
        @escaping (ElementOfResult, Elements.Element) -> ElementOfResult
    ) -> Publishers.Sequence<[ElementOfResult], Failure> {
        var accumulator = initialResult
        return .init(sequence: sequence.map {
            accumulator = nextPartialResult(accumulator, $0)
            return accumulator
        })
    }
    
    public func setFailureType<NewFailure: Error>(
        to error: NewFailure.Type
    ) -> Publishers.Sequence<Elements, NewFailure> {
        return .init(sequence: sequence)
    }
}

extension Publishers.Sequence where Elements.Element: Equatable {
    
    public func removeDuplicates() -> Publishers.Sequence<[Elements.Element], Failure> {
        var previous: Elements.Element?
        var result = [Elements.Element]()
        for element in sequence where element != previous {
            result.append(element)
            previous = element
        }
        return .init(sequence: result)
    }
    
    public func contains(
        _ output: Elements.Element
    ) -> Result<Bool, Failure>.OCombine.Publisher {
        return .init(sequence.contains(output))
    }
}

extension Publishers.Sequence where Failure == Never, Elements.Element: Comparable {
    
    public func min() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.min())
    }
    
    public func max() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.max())
    }
}

extension Publishers.Sequence where Elements: Collection, Failure == Never {
    
    public func first() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.first)
    }
    
    public func output(
        at index: Elements.Index
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.indices.contains(index) ? sequence[index] : nil)
    }
}

extension Publishers.Sequence where Elements: Collection {
    
    public func count() -> Result<Int, Failure>.OCombine.Publisher {
        return .init(sequence.count)
    }
    
    public func output(
        in range: Range<Elements.Index>
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: Array(sequence[range]))
    }
}

extension Publishers.Sequence where Elements: BidirectionalCollection, Failure == Never {
    
    public func last() -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.last)
    }
    
    public func last(
        where predicate: (Elements.Element) -> Bool
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.last(where: predicate))
    }
}

extension Publishers.Sequence where Elements: RandomAccessCollection, Failure == Never {
    
    public func output(
        at index: Elements.Index
    ) -> Optional<Elements.Element>.OCombine.Publisher {
        return .init(sequence.indices.contains(index) ? sequence[index] : nil)
    }
    
    public func count() -> Just<Int> {
        return .init(sequence.count)
    }
}

extension Publishers.Sequence where Elements: RandomAccessCollection {
    
    public func output(
        in range: Range<Elements.Index>
    ) -> Publishers.Sequence<[Elements.Element], Failure> {
        return .init(sequence: Array(sequence[range]))
    }
    
    public func count() -> Result<Int, Failure>.OCombine.Publisher {
        return .init(sequence.count)
    }
}

extension Publishers.Sequence where Elements: RangeReplaceableCollection {
    
    public func prepend(
        _ elements: Elements.Element...
    ) -> Publishers.Sequence<Elements, Failure> {
        return prepend(elements)
    }
    
    public func prepend<OtherSequence: Sequence>(
        _ elements: OtherSequence
    ) -> Publishers.Sequence<Elements, Failure>
    where OtherSequence.Element == Elements.Element
    {
        var result = Elements()
        result.reserveCapacity(
            sequence.count + elements.underestimatedCount
        )
        result.append(contentsOf: elements)
        result.append(contentsOf: sequence)
        return .init(sequence: result)
    }
    
    public func prepend(
        _ publisher: Publishers.Sequence<Elements, Failure>
    ) -> Publishers.Sequence<Elements, Failure> {
        var result = publisher.sequence
        result.append(contentsOf: sequence)
        return .init(sequence: result)
    }
    
    public func append(
        _ elements: Elements.Element...
    ) -> Publishers.Sequence<Elements, Failure> {
        return append(elements)
    }
    
    public func append<OtherSequence: Sequence>(
        _ elements: OtherSequence
    ) -> Publishers.Sequence<Elements, Failure>
    where OtherSequence.Element == Elements.Element
    {
        var result = sequence
        result.append(contentsOf: elements)
        return .init(sequence: result)
    }
    
    public func append(
        _ publisher: Publishers.Sequence<Elements, Failure>
    ) -> Publishers.Sequence<Elements, Failure> {
        return append(publisher.sequence)
    }
}

extension Sequence {
    // 原来, (1...3).publisher 是到了这里. 生成了一个 Publishers.Sequence<Self, Never> 对象.
    public var publisher: Publishers.Sequence<Self, Never> {
        return .init(sequence: self)
    }
}
