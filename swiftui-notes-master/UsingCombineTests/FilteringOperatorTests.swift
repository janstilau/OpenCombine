//
//  FilteringOperatorTests.swift
//  UsingCombineTests
//
//  Created by Joseph Heck on 12/15/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import XCTest

class FilteringOperatorTests: XCTestCase {
    enum TestExampleError: Error {
        case example
    }

    func testReplaceNil() {
        // 如果这里吧 String? 变为 String, replaceNil 就不能用了
        let passSubj = PassthroughSubject<String?, Never>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String] = []

        let cancellable = passSubj
            .print(debugDescription)
            .replaceNil(with: "-replacement-")
            .sink { someValue in
                print("value updated to: ", someValue)
                receivedList.append(someValue)
            }

        passSubj.send("one")
        passSubj.send(nil)
        passSubj.send("")
        passSubj.send(nil)
        passSubj.send("five")
        passSubj.send(completion: Subscribers.Completion.finished)

        XCTAssertEqual(receivedList, ["one", "-replacement-", "", "-replacement-", "five"])
        XCTAssertNotNil(cancellable)
    }

    func testReplaceEmptyWithValues() {
        let passSubj = PassthroughSubject<String?, Never>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String?] = []

        let cancellable = passSubj
            .print(debugDescription)
            .replaceEmpty(with: "-replacement-")
            .sink { someValue in
                print("value updated to: ", someValue as Any)
                receivedList.append(someValue)
            }

        passSubj.send("one")
        passSubj.send(nil) // Nil 也是一个合法的值.
        passSubj.send("")
        passSubj.send(completion: Subscribers.Completion.finished)

        XCTAssertEqual(receivedList, ["one", nil, ""])
        XCTAssertNotNil(cancellable)
    }

    func testReplaceEmptyNoValues() {
        let passSubj = PassthroughSubject<String?, Never>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String?] = []

        let cancellable = passSubj
            .print(debugDescription)
            .replaceEmpty(with: "-replacement-")
            .sink { someValue in
                print("value updated to: ", someValue as Any)
                receivedList.append(someValue)
            }

        // 直接发送了结束事件.
        passSubj.send(completion: Subscribers.Completion.finished)

        XCTAssertEqual(receivedList, ["-replacement-"])
        XCTAssertNotNil(cancellable)
    }

    func testReplaceEmptyWithFailure() {
        let passSubj = PassthroughSubject<String, Error>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String] = []

        // 这里说明, replaceEmpty 只会在 finished 的时候起作用.
        let cancellable = passSubj
            .print(debugDescription)
            .replaceEmpty(with: "-replacement-")
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                switch completion {
                case .finished:
                    XCTFail()
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                receivedList.append(responseValue)
                XCTFail()
            })

        passSubj.send(completion: Subscribers.Completion.failure(TestExampleError.example))

        XCTAssertEqual(receivedList, [])
        XCTAssertNotNil(cancellable)
    }

    func testCompactMap() {
        let passSubj = PassthroughSubject<String?, Never>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String] = []

        let cancellable = passSubj
            .print(debugDescription)
        /*
         Combine’s compactMap(_:) operator performs a function similar to that of compactMap(_:) in the Swift standard library: the compactMap(_:) operator in Combine removes nil elements in a publisher’s stream and republishes non-nil elements to the downstream subscriber.
         The example below uses a range of numbers as the source for a collection based publisher. The compactMap(_:) operator consumes each element from the numbers publisher attempting to access the dictionary using the element as the key. If the example’s dictionary returns a nil, due to a non-existent key, compactMap(_:) filters out the nil (missing) elements.
         
         Combine 中的 compactMap(_:) 操作符执行的功能类似于 Swift 标准库中的 compactMap(_:)：Combine 中的 compactMap(_:) 操作符会从发布者的流中移除 nil 元素，并将非 nil 元素重新发布给下游订阅者。

         下面的示例使用一个数字范围作为基于集合的发布者的源。compactMap(_:) 操作符会消耗来自数字发布者的每个元素，尝试使用该元素作为键访问字典。如果示例中的字典返回 nil，表示键不存在，compactMap(_:) 将过滤掉 nil（缺失）元素。
         */
        // 所以 compactMap 里面还是要返回值的, 只不过返回值中的 nil 被 operator 内部干掉了.
            .compactMap { value in
                value
            }
            .sink { someValue in
                print("value updated to: ", someValue as Any)
                receivedList.append(someValue)
            }

        passSubj.send("one")
        passSubj.send(nil)
        passSubj.send("")
        passSubj.send(completion: Subscribers.Completion.finished)

        XCTAssertEqual(receivedList, ["one", ""])
        XCTAssertNotNil(cancellable)
    }

    func testTryCompactMap() {
        let passSubj = PassthroughSubject<String?, Never>()
        // no initial value is propagated from a PassthroughSubject

        var receivedList: [String] = []

        let cancellable = passSubj
            .tryCompactMap { someVal -> String? in
                if someVal == "boom" {
                    throw TestExampleError.example
                }
                return someVal
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                switch completion {
                case .finished:
                    XCTFail()
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                receivedList.append(responseValue)
                print(".sink() data received \(responseValue)")
            })

        passSubj.send("one")
        passSubj.send(nil) 
        passSubj.send("")
        passSubj.send("boom")
        passSubj.send(completion: Subscribers.Completion.finished)

        XCTAssertEqual(receivedList, ["one", ""])
        XCTAssertNotNil(cancellable)
    }
}
