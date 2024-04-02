import XCTest
import Combine


// 对于 Combine 的这里大部分的测试例子, 其实都是用的 Sink 来进行收集, 最后判断收集的数据是否和预想的值相等而已. 
class CombineOperatorsTests: XCTestCase {
    var subscriptions = Set<AnyCancellable>()
    
    override func tearDown() {
        // 所有的注册, 都添加到了 subscriptions
        // 这样, 每一个方法结束的时候, 可以重新进行环境的清空
        subscriptions = []
    }
    
    func test_collect() {
        // Given
        let values = [0, 1, 2]
        let publisher = values.publisher
        
        // When
        publisher
            .collect()
            .sink(receiveValue: {
                // Then
                XCTAssert(
                    $0 == values,
                    "Result was expected to be \(values) but was \($0)"
                )
            })
            .store(in: &subscriptions)
    }
    
    func test_flatMapWithMax2Publishers() {
        // Given
        // 1
        let intSubject1 = PassthroughSubject<Int, Never>()
        let intSubject2 = PassthroughSubject<Int, Never>()
        let intSubject3 = PassthroughSubject<Int, Never>()
        
        // 2
        let publisher = CurrentValueSubject<PassthroughSubject<Int, Never>, Never>(intSubject1)
        
        // 3
        let expected = [1, 2, 4]
        var results = [Int]()
        
        // 4
        publisher
        // Transforms all elements from an upstream publisher into a new publisher up to a maximum number of publishers you specify.
            .flatMap(maxPublishers: .max(2)) { $0 }
            .sink(receiveValue: {
                results.append($0)
            })
            .store(in: &subscriptions)
        
        // When
        // 5
        intSubject1.send(1)
        
        // 6
        publisher.send(intSubject2)
        intSubject2.send(2)
        
        // 7
        publisher.send(intSubject3)
        intSubject3.send(3)
        intSubject2.send(4)
        intSubject1.send(5)
        
        // 8
        publisher.send(completion: .finished)
        
        // Then
        XCTAssert(
            results == expected,
            "Results expected to be \(expected) but were \(results)"
        )
    }
    
    func test_timerPublish() {
        // Given
        // 1
        func normalized(_ ti: TimeInterval) -> TimeInterval {
            return Double(round(ti * 10) / 10)
        }
        
        // 2
        let now = Date().timeIntervalSinceReferenceDate
        // 3
        let expectation = self.expectation(description: #function)
        // 4
        let expected = [0.5, 1, 1.5]
        var results = [TimeInterval]()
        
        // 5
        let publisher = Timer
            .publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .prefix(3)
        
        // When
        publisher
            .sink(
                receiveCompletion: { _ in expectation.fulfill() },
                receiveValue: {
                    results.append(
                        normalized($0.timeIntervalSinceReferenceDate - now)
                    )
                }
            )
            .store(in: &subscriptions)
        
        // Then
        // 6
        waitForExpectations(timeout: 2, handler: nil)
        
        // 7
        XCTAssert(
            results == expected,
            "Results expected to be \(expected) but were \(results)"
        )
    }
    
    func test_shareReplay() {
        // Given
        // 1
        let subject = PassthroughSubject<Int, Never>()
        // 2
        let publisher = subject.shareReplay(capacity: 2)
        // 3
        let expected = [0, 1, 2, 1, 2, 3, 3]
        var results = [Int]()
        
        // When
        // 4
        publisher
            .sink(receiveValue: { results.append($0) })
            .store(in: &subscriptions)
        
        // 5
        subject.send(0)
        subject.send(1)
        subject.send(2)
        
        // 6
        publisher
            .sink(receiveValue: { results.append($0) })
            .store(in: &subscriptions)
        
        // 7
        subject.send(3)
        
        XCTAssert(
            results == expected,
            "Results expected to be \(expected) but were \(results)"
        )
    }
}
