//
//  FilterPublisherTests.swift
//  UsingCombineTests
//
//  Created by Joseph Heck on 7/11/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import XCTest

class FilterPublisherTests: XCTestCase {
    func testFilter() {
        let simplePublisher = PassthroughSubject<String, Error>()
        
        let cancellable = simplePublisher
        // 只有 Filter 返回 True 的 Value, 才会在 pipeline 里面流转.
            .filter { stringValue in
                stringValue == "onefish"
            }
            .print(debugDescription)
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion:", String(describing: completion))
                switch completion {
                case let .failure(anError):
                    print(".sink() received completion error: ", anError)
                    XCTFail("no error should be received")
                case .finished:
                    break
                }
            }, receiveValue: { stringValue in
                // 因为前面的 Filter, 所以这里能够到达的 value, 一定就是 onefish
                print(".sink() received \(stringValue)")
                XCTAssertEqual(stringValue, "onefish")
            })
        
        simplePublisher.send("onefish") // onefish will pass the filter
        simplePublisher.send("twofish") // twofish will not
        simplePublisher.send(completion: Subscribers.Completion.finished)
        XCTAssertNotNil(cancellable)
    }
    
    func testTryFilter() {
        enum TestFailure: Error {
            case boom
        }
        
        let simplePublisher = PassthroughSubject<String, Error>()
        
        let cancellable = simplePublisher
            .tryFilter { stringValue in
                // 原来, 在 Combine 里面, 有这么多的 Try 相关的方法.
                // 给下游提供了对应的 Error 版本.
                if stringValue == "explode" {
                    throw TestFailure.boom
                }
                return stringValue == "onefish"
            }
            .print(debugDescription)
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion:", String(describing: completion))
                switch completion {
                case let .failure(anError):
                    print(".sink() received completion error: ", anError)
                case .finished:
                    // 当 explode 发送的时候, 会触发 Error 的抛出, 然后这个 Pipeline 就结束了. 
                    XCTFail("test sequence should fail before receiving finished")
                }
            }, receiveValue: { stringValue in
                print(".sink() received \(stringValue)")
                XCTAssertEqual(stringValue, "onefish")
            })
        
        simplePublisher.send("onefish") // onefish will pass the filter
        simplePublisher.send("twofish") // twofish will not
        simplePublisher.send("explode") // explode will trigger a failure
        simplePublisher.send(completion: Subscribers.Completion.finished)
        XCTAssertNotNil(cancellable)
    }
}
