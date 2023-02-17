//
//  ViewController.swift
//  AnalysisCombine
//
//  Created by JustinLau on 2022/4/25.
//

import UIKit
import OpenCombine
import OpenCombineFoundation
import OpenCombineDispatch

class Weather {
    @OpenPublished var temperature: Double
    init(temperature: Double) {
        self.temperature = temperature
    }
    
    func change() {
        // self 是 imutable 的.
        // self = Weather()
    }
}



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

        let weather = Weather(temperature: 20)
        let cancleable = weather.$temperature.sink() {
            print ("Temperature now: \($0)")
        }
        weather.temperature = 25
        weather.temperature = 23
        weather.temperature = 21
    }
    
    func getProtocolFunc(_ sth: SomeProtocol) {
        self.theAction = sth.doSth
        self.theAction?()
    }

}

