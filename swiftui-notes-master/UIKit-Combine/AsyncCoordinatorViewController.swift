//
//  AsyncCoordinatorViewController.swift
//  UIKit-Combine
//
//  Created by Joseph Heck on 7/21/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import UIKit

class AsyncCoordinatorViewController: UIViewController {
    @IBOutlet var startButton: UIButton!
    
    @IBOutlet var step1_button: UIButton!
    @IBOutlet var step2_1_button: UIButton!
    @IBOutlet var step2_2_button: UIButton!
    @IBOutlet var step2_3_button: UIButton!
    @IBOutlet var step3_button: UIButton!
    @IBOutlet var step4_button: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var cancellable: AnyCancellable?
    var coordinatedPipeline: AnyPublisher<Bool, Error>?
    
    @IBAction func doit(_: Any) {
        runItAll()
    }
    
    func runItAll() {
        if let cancellable = cancellable {
            print("Cancelling existing run")
            cancellable.cancel()
            activityIndicator.stopAnimating()
        }
        print("resetting all the steps")
        // 在开始的阶段, 将所有的 Btn 进行回置处理.
        resetAllSteps()
        // driving it by attaching it to .sink
        activityIndicator.startAnimating()
        print("attaching a new sink to start things going")
        // 信号源, 是 ViewDidLoad 里面进行的创建, 然后在每次进行点击的时候, 才会创建出真正的响应者链条.
        cancellable = coordinatedPipeline?
            .print()
            .sink(receiveCompletion: { completion in
                print(".sink() received the completion: ", String(describing: completion))
                self.activityIndicator.stopAnimating()
            }, receiveValue: { value in
                print(".sink() received value: ", value)
            })
    }
    
    // MARK: - helper pieces that would normally be in other files
    
    // this emulates an async API call with a completion callback
    // it does nothing other than wait and ultimately return with a boolean value
    func randomAsyncAPI(completion completionBlock: @escaping ((Bool, Error?) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            sleep(.random(in: 1 ... 4))
            completionBlock(true, nil)
        }
    }
    
    /// Creates and returns pipeline that uses a Future to wrap randomAsyncAPI, then updates a UIButton to represent
    /// the completion of the async work before returning a boolean True
    /// - Parameter button: button to be updated
    func createFuturePublisher(button: UIButton) -> AnyPublisher<Bool, Error> {
        return Future<Bool, Error> { promise in
            // 这 Promise 的设计里面一样, Promise 是一个闭包, 真正的状态的改变, 是 Promise 来实现的.
            self.randomAsyncAPI { result, err in
                if let err = err {
                    promise(.failure(err))
                } else {
                    promise(.success(result))
                }
            }
        }
        .receive(on: RunLoop.main)
        // so that we can update UI elements to show the "completion"
        // of this step
        .map { _ -> Bool in
            // intentially side effecting here to show progress of pipeline
            // 非常垃圾的代码, 在 Map 中, 添加了副作用.
            self.markStepDone(button: button)
            return true
        }
        .eraseToAnyPublisher()
    }
    
    /// highlights a button and changes the background color to green
    /// - Parameter button: reference to button being updated
    func markStepDone(button: UIButton) {
        button.backgroundColor = .systemGreen
        button.isHighlighted = true
    }
    
    func resetAllSteps() {
        for button in [step1_button, step2_1_button, step2_2_button, step2_3_button, step3_button, step4_button] {
            button?.backgroundColor = .lightGray
            button?.isHighlighted = false
        }
        activityIndicator.stopAnimating()
    }
    
    // MARK: - view setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.stopAnimating()
        
        // Do any additional setup after loading the view.
        
        coordinatedPipeline = createFuturePublisher(button: step1_button)
            .flatMap { _ -> AnyPublisher<Bool, Error> in
                // 使用了 flatMap, 创建出一个新的信号源来. 后续的节点, 是接收该信号源提供的各项数据.
                let step2_1 = self.createFuturePublisher(button: self.step2_1_button)
                let step2_2 = self.createFuturePublisher(button: self.step2_2_button)
                let step2_3 = self.createFuturePublisher(button: self.step2_3_button)
                return Publishers.Zip3(step2_1, step2_2, step2_3)
                    .map { _ -> Bool in
                        true
                    }
                    .eraseToAnyPublisher()
            }
            .flatMap { _ in
                // 使用了 FlatMap, 创建出一个新的信号源来, 后续的节点, 是接收该信号源的数据.
                // flatMap 是触发一个新的异步操作的很好的办法.
                self.createFuturePublisher(button: self.step3_button)
            }
            .flatMap { _ in
                // 使用了 FlatMap, 创建出一个新的信号源来, 后续的节点, 是接收该信号源的数据.
                // flatMap 是触发一个新的异步操作的很好的办法.
                self.createFuturePublisher(button: self.step4_button)
            }
            .eraseToAnyPublisher()
    }
}
