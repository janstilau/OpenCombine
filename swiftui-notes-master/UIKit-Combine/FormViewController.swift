//
//  FormViewController.swift
//  UIKit-Combine
//
//  Created by Joseph Heck on 7/19/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import UIKit

class FormViewController: UIViewController {
    // 所有的 UI 相关的属性, 是通过 Xib 进行的初始化.
    @IBOutlet var value1_input: UITextField!
    @IBOutlet var value2_input: UITextField!
    @IBOutlet var value2_repeat_input: UITextField!
    @IBOutlet var submission_button: UIButton!
    @IBOutlet var value1_message_label: UILabel!
    @IBOutlet var value2_message_label: UILabel!
    
    @Published var value1: String = ""
    @Published var value2: String = ""
    @Published var value2_repeat: String = ""

    // 在 Vc 里面, 实现 ViewAction, 是去触发, 对应的 @Publihsed 的属性的修改.
    // @Publihsed 属性, 中间藏了一个 PublishedObject, 每次 Publihsed 的赋值操作, 都会引起该 Subject 的 send 方法被调用.
    @IBAction func value1_updated(_ sender: UITextField) {
        value1 = sender.text ?? ""
    }

    @IBAction func value2_updated(_ sender: UITextField) {
        value2 = sender.text ?? ""
    }

    @IBAction func value2_repeat_updated(_ sender: UITextField) {
        value2_repeat = sender.text ?? ""
    }

    // 在 ViewModel 里面, 组织原有的 Signal, 来组合成为新的 Signal, 这是一个常见的组织方式.
    var validatedValue1: AnyPublisher<String?, Never> {
        // 这里的代码有点问题, 使用 HandleEvent 是更加好的方式.
        // 这是一个不好的代码组织的方式, map 里面, 带有了副作用.
        return $value1.map { value1 in
            guard value1.count > 2 else {
                DispatchQueue.main.async {
                    self.value1_message_label.text = "minimum of 3 characters required"
                }
                return nil
            }
            DispatchQueue.main.async {
                self.value1_message_label.text = ""
            }
            return value1
        }.eraseToAnyPublisher()
    }

    var validatedValue2: AnyPublisher<String?, Never> {
        //非常奇怪的代码, 我怀疑这个作者, 是不是真正的理解 Combine 的使用. 
        return Publishers.CombineLatest($value2, $value2_repeat)
            .receive(on: RunLoop.main)
            .map { value2, value2_repeat in
                guard value2_repeat == value2, value2.count > 4 else {
                    self.value2_message_label.text = "values must match and have at least 5 characters"
                    return nil
                }
                self.value2_message_label.text = ""
                return value2
            }.eraseToAnyPublisher()
    }

    var readyToSubmit: AnyPublisher<(String, String)?, Never> {
        return Publishers.CombineLatest(validatedValue2, validatedValue1)
            .map { value2, value1 in
                guard let realValue2 = value2, let realValue1 = value1 else {
                    return nil
                }
                return (realValue2, realValue1)
            }
            .eraseToAnyPublisher()
    }

    private var cancellableSet: Set<AnyCancellable> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        readyToSubmit
            .map { $0 != nil }
            .receive(on: RunLoop.main)
            .assign(to: \.isEnabled, on: submission_button)
            .store(in: &cancellableSet)
    }
}
