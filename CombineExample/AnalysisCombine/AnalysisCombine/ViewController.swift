//
//  ViewController.swift
//  AnalysisCombine
//
//  Created by JustinLau on 2022/4/25.
//

import UIKit
import OpenCombine

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

    override func viewDidLoad() {
        super.viewDidLoad()
        (1...3).publisher
        
//        var thePerson = Person()
//        thePerson.name = "Custom Name"
//        thePerson.age = 150
//        self.theAction = thePerson.say
        
        let valeu = 100
        self.theAction = valeu.introPrint
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.theAction?()
//        self.theAction = nil
        let value = 200
        getProtocolFunc(value)
    }
    
    func getProtocolFunc(_ sth: SomeProtocol) {
        self.theAction = sth.doSth
        self.theAction?()
    }

}

