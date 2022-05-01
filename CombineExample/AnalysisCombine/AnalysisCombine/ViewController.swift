//
//  ViewController.swift
//  AnalysisCombine
//
//  Created by JustinLau on 2022/4/25.
//

import UIKit
import OpenCombine
//import Combine

protocol SomeProtocol {
    func doSth()
}

extension Int: SomeProtocol {
    func doSth() {
        print("Int \(self) doSth")
    }
}

extension Int {
    func introPrint() {
        print("Int Print \(self)")
    }
}

class Cat {
    deinit {
        print("The Cat is Deinit")
    }
}

struct Person {
    var age = 100
    var name = "The Person Name"
    var cat = Cat()
    func say() {
        print(name)
        print(age)
    }
}

class ViewController: UIViewController {
    
    var theAction: (() -> ())?
    
    var cancellable1: Cancellable?
    var cancellable2: Cancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        let pub =
        (1...3).publisher
            .map( { _ in return Int.random(in: 0...100) } )
            .print("Random")
            .multicast(subject: PassthroughSubject())

        cancellable1 = pub
            .sink { print ("Stream 1 received: \($0)")}
        cancellable2 = pub
            .sink { print ("Stream 2 received: \($0)")}
        
//        pub.connect()
    }
    
    func getProtocolFunc(_ sth: SomeProtocol) {
        self.theAction = sth.doSth
        self.theAction?()
    }

}

