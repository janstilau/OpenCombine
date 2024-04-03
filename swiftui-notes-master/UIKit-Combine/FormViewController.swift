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
    @IBOutlet var value1_input: UITextField!
    @IBOutlet var value2_input: UITextField!
    @IBOutlet var value2_repeat_input: UITextField!
    @IBOutlet var submission_button: UIButton!
    @IBOutlet var value1_message_label: UILabel!
    @IBOutlet var value2_message_label: UILabel!
    
    // ViewAction, 会引起信号的变化.
    @IBAction func value1_updated(_ sender: UITextField) {
        value1 = sender.text ?? ""
    }
    
    @IBAction func value2_updated(_ sender: UITextField) {
        value2 = sender.text ?? ""
    }
    
    @IBAction func value2_repeat_updated(_ sender: UITextField) {
        value2_repeat = sender.text ?? ""
    }
    
    // UIKit 到 Combine, 是需要进行桥接的. 在这里, 作者使用到了 @Published 做的桥接.
    // 每次 @Published 的属性发生改变的时候, 都会出发对应的属性 Publisher 发出信号.
    // 在 ViewDidLoad 里面, 做的就是各种的信号绑定的工作, 这其实和各种 onXXXX 所做的事情是一样的.
    @Published var value1: String = ""
    @Published var value2: String = ""
    @Published var value2_repeat: String = ""
    
    // 信号的再次加工. 但是这里大部分都是副作用.
    var validatedValue1: AnyPublisher<String?, Never> {
        return $value1.map { value1 in
            // 这里使用 map, 是为了过滤那些非法的数据.
            guard value1.count > 2 else {
                // 这里有副作用, 不是一个好的实现. 将 Map 进行了错误的使用. 
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
    
    // Bag 对象.
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
