//
//  ViewController.swift
//  CombineExamples
//
//  Created by Pawel Krawiec on 17/06/2019.
//  Copyright © 2019 tailec. All rights reserved.
//

import UIKit
import Combine

class LoginViewController: UIViewController {
    
    @IBOutlet weak private var usernameTextField: UITextField!
    @IBOutlet weak private var passwordTextField: UITextField!
    @IBOutlet weak private var loginButton: UIButton!
    @IBOutlet weak private var activityIndicator: UIActivityIndicatorView!
    
    // 实际上, 都使用 Subject 也是可以的. @Published 相当于是将这个过程, 隐藏到了自己的赋值语句中了.
    @Published private var username: String = ""
    @Published private var password: String = ""
    private let loginTaps = PassthroughSubject<Void, Never>()
    
    private let executing = CurrentValueSubject<Bool, Never>(false)
    private var cancellableBag = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /*
         根据, 之前 Rx 里面的实现. CombineLatest 会在内部注册成为所监听的 Publisher 节点.
         然后在每次收到上游事件之后, 如果上游都已经 Publish 过了, 将存储的值组成成为一个 Tuple 对象, 然后发送给下游.
         */
        let credentials = Publishers.CombineLatest($username, $password)
            .share()
        
        credentials
            .map { uname, pass in
                return uname.count >= 4 && pass.count >= 4
            }
            .prepend(false) // initial state
            .assign(to: \.isEnabled, on: loginButton)
            .store(in: &cancellableBag)
        
        loginTaps
            .withLatestFrom(credentials)
        // HandleEvent 应该就是 do 吧.
            .handleEvents(receiveOutput: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.executing.send(true)
            })
            .flatMapLatest { uname, pass in
                URLSession.shared.get(url: URL(string: "https://postman-echo.com/basic-auth")!,
                                      params: ["username": uname,
                                               "password": pass,
                                               "Authorization": "Basic cG9zdG1hbjpwYXNzd29yZA=="])
                    .retry(3)
                    .decode(type: AuthResponse.self, decoder: JSONDecoder())
                    .map { $0.authenticated }
                    .replaceError(with: false)
            }
            .handleEvents(receiveOutput: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.executing.send(false)
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
            .sink(receiveValue: { [weak self] result in
                guard let strongSelf = self else { return }
                let alert = UIAlertController(title: result ? "Success!" : "Failure!", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                strongSelf.present(alert, animated: true)
            })
            .store(in: &cancellableBag)
        
        // executing 的改变, 是在上述的网络交互的过程中进行的改变.
        executing
            .map(!)
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
            .assign(to: \.isHidden, on: activityIndicator)
            .store(in: &cancellableBag)
    }
    
    /*
     不太了解, 这是不是 Combine 的正常用法.
     @Published 中, 其实就是藏了一个 Subject 的对象. 所以, 这里其实都是用 Subject 这个对象, 来将响应式, 变化成为了响应式.
     */
    @IBAction func usernameDidChange(_ sender: UITextField) {
        username = sender.text ?? ""
    }
    
    @IBAction func passwordDidChange(_ sender: UITextField) {
        password = sender.text ?? ""
    }
    
    // 原有的 Target Action, 触发了 Subject 的改动. 而 Subject 下面, 进行了各种回调的注册.
    @IBAction func loginDidTap(_ sender: UIButton) {
        loginTaps.send()
    }
}

private struct AuthResponse: Decodable {
    let authenticated: Bool
}
