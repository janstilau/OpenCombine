//
//  FailedPublisherTests.swift
//  UsingCombineTests
//
//  Created by Joseph Heck on 8/11/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import XCTest

/*
 /// A publisher that immediately terminates with the specified error.
 @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
 public struct Fail<Output, Failure> : Publisher where Failure : Error {

     /// Creates a publisher that immediately terminates with the specified failure.
     /// - Parameter error: The failure to send when terminating the publisher.
     public init(error: Failure)

     /// Creates publisher with the given output type, that immediately terminates with the specified failure.
     ///
     /// Use this initializer to create a `Fail` publisher that can work with subscribers or publishers that expect a given output type.
     ///
     /// - Parameters:
     ///   - outputType: The output type exposed by this publisher.
     ///   - failure: The failure to send when terminating the publisher.
     public init(outputType: Output.Type, failure: Failure)

     /// The failure to send when terminating the publisher.
     public let error: Failure

     /// Attaches the specified subscriber to this publisher.
     ///
     /// Implementations of ``Publisher`` must implement this method.
     ///
     /// The provided implementation of ``Publisher/subscribe(_:)-4u8kn``calls this method.
     ///
     /// - Parameter subscriber: The subscriber to attach to this ``Publisher``, after which it can receive values.
     public func receive<S>(subscriber: S) where Output == S.Input, Failure == S.Failure, S : Subscriber
 }

 */
class FailedPublisherTests: XCTestCase {
    enum TestFailureCondition: Error {
        case exampleFailure
    }
    
    func testFailPublisher() {
        let expectation = XCTestExpectation(description: debugDescription)
        
        // Fail 只能够用来, 生成错误.
        let cancellable = Fail<String, Error>(error: TestFailureCondition.exampleFailure)
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                switch completion {
                case .finished:
                    // XCTFail 是直接表示, 出错了.
                    XCTFail("No finished should be received from empty")
                case let .failure(anError):
                    print("received error: ", anError)
                }
                expectation.fulfill()
            }, receiveValue: { responseValue in
                XCTFail("No vaue should be received from empty")
                print(".sink() data received \(responseValue)")
            })
        
        // Combine 是一个事件处理的框架, 所以使用 wait 来进行测试, 是非常有必要的.
        // 因为根本就不知道, 这个 Operator 是否是同步的还是异步的.
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(cancellable)
    }
    
    func testFailPublisherAltInitializer() {
        let expectation = XCTestExpectation(description: debugDescription)
        
        // Fail 的另外一个初始化方法, 不指定类型, 通过参数来确认.
        let cancellable = Fail(outputType: String.self, failure: TestFailureCondition.exampleFailure)
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                switch completion {
                case .finished:
                    XCTFail("No finished should be received from empty")
                case let .failure(anError):
                    print("received error: ", anError)
                }
                expectation.fulfill()
            }, receiveValue: { responseValue in
                XCTFail("No vaue should be received from empty")
                print(".sink() data received \(responseValue)")
            })
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(cancellable)
    }
    
    func testSetFailureTypePublisher() {
        let expectation = XCTestExpectation(description: debugDescription)
        
        let initialSequence = ["one", "two", "red", "blue"]
        
        // 连续发送四个数据之后, 然后 fulfill
        let cancellable = initialSequence.publisher
        // 使用了 setFailureType, 使得后面的 Sink 里面的类型, 变为了 TestFailureCondition
            .setFailureType(to: TestFailureCondition.self)
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
                expectation.fulfill()
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
            })
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(cancellable)
    }
}
