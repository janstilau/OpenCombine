import Foundation
import Combine

// 1
let computationPublisher = Publishers.ExpensiveComputation(duration: 3)

// 2
let queue = DispatchQueue(label: "serial queue")

// 3
let currentThread = Thread.current.number
print("Start computation publisher on thread \(currentThread)")

let subscription = computationPublisher
    .subscribe(on: queue)
    .receive(on: DispatchQueue.main)
    .sink { value in
        let thread = Thread.current.number
        print("Received computation result on thread \(thread): '\(value)'")
    }

