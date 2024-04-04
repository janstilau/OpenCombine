//
//  CriteriaOperatorTests.swift
//  UsingCombineTests
//
//  Created by Joseph Heck on 12/19/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import XCTest

class CriteriaOperatorTests: XCTestCase {
    enum TestExampleError: Error {
        case invalidValue
    }
    
    func testContains() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .contains("abc")
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("world")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        
        
        // 当 abc 收到了之后, 这个 Publisher 也就结束了.
        passSubj.send("abc")
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [true])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testContainsFinished() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .contains("abc")
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send(completion: Subscribers.Completion.finished)
        // 当结束了还没有出现, 也会收到 value
        
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [false])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testContainsWhere() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .contains { someval -> Bool in
                someval == "abc"
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("abc")
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [true])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testContainsWhereFinished() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .contains { someval -> Bool in
                someval == "abc"
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send(completion: Subscribers.Completion.finished)
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [false])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testTryContainsWhere() {
        enum TestExampleError: Error {
            case invalidValue
        }
        
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .tryContains { someval -> Bool in
                if someval == "boom" {
                    throw TestExampleError.invalidValue
                }
                return someval == "abc"
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("abc")
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [true])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testTryContainsWhereWithError() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .tryContains { someval -> Bool in
                if someval == "boom" {
                    throw TestExampleError.invalidValue
                }
                return someval == "abc"
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                responses.append(responseValue)
                print(".sink() data received \(responseValue)")
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("boom")
        // 当出现了错误的时候, 其实是不会走 receive value 的逻辑的
        XCTAssertEqual(responses.count, 0)
        XCTAssertTrue(terminatedStream)
        // passSubj.send("abc")
        // XCTAssertEqual(responses.count, 1)
        // XCTAssertEqual(responses, [true])
        // XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testAllSatisfyWithFailure() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .allSatisfy { someval -> Bool in
                someval.count > 3
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                responses.append(responseValue)
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("world")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        // 这里没有达到目标. 直接触发了 finish
        passSubj.send("abc")
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [false])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testAllSatisfyWithFinish() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .allSatisfy { someval -> Bool in
                someval.count > 3
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                responses.append(responseValue)
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("world")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        // 这里触发了 finish, 会触发 receive value.
        passSubj.send(completion: Subscribers.Completion.finished)
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [true])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testTryAllSatisfyWithFinish() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .tryAllSatisfy { someval -> Bool in
                if someval == "boom" {
                    throw TestExampleError.invalidValue
                }
                return (someval.count > 3)
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                responses.append(responseValue)
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("world")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send(completion: Subscribers.Completion.finished)
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [true])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testTryAllSatisfyWithFailure() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .tryAllSatisfy { someval -> Bool in
                if someval == "boom" {
                    throw TestExampleError.invalidValue
                }
                return (someval.count > 3)
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                responses.append(responseValue)
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("world")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        // 这里触发了非法的条件, 提前结束了 pipeline
        passSubj.send("foo")
        XCTAssertEqual(responses.count, 1)
        XCTAssertEqual(responses, [false])
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
    
    func testTryAllSatisfyWithError() {
        let passSubj = PassthroughSubject<String, Never>()
        // no initial value is propagated from a PassthroughSubject
        
        var responses = [Bool]()
        var terminatedStream = false
        
        let cancellable = passSubj
            .tryAllSatisfy { someval -> Bool in
                if someval == "boom" {
                    throw TestExampleError.invalidValue
                }
                return (someval.count > 3)
            }
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion", String(describing: completion))
                terminatedStream = true
                switch completion {
                case .finished:
                    break
                case let .failure(anError):
                    print("received error: ", anError)
                }
            }, receiveValue: { responseValue in
                print(".sink() data received \(responseValue)")
                responses.append(responseValue)
            })
        
        passSubj.send("hello")
        XCTAssertEqual(responses.count, 0)
        XCTAssertFalse(terminatedStream)
        passSubj.send("boom")
        XCTAssertEqual(responses.count, 0)
        XCTAssertTrue(terminatedStream)
        
        XCTAssertNotNil(cancellable)
    }
}
