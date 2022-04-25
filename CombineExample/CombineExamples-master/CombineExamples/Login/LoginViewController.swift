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
    
    @Published private var username: String = ""
    @Published private var password: String = ""
    private let loginTaps = PassthroughSubject<Void, Never>()
    
    private let executing = CurrentValueSubject<Bool, Never>(false)
    private var cancellableBag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        //
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
