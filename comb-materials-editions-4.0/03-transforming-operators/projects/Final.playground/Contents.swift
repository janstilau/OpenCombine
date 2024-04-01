import Foundation
import Combine

var subscriptions = Set<AnyCancellable>()

example(of: "collect") {
    ["A", "B", "C", "D", "E"].publisher
        .collect(2)
        .sink(receiveCompletion: { print($0) },
              receiveValue: { print($0) })
        .store(in: &subscriptions)
}

example(of: "map") {
    // 1
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    
    // 2
    [123, 4, 56].publisher
    // 3
        .map {
            formatter.string(for: NSNumber(integerLiteral: $0)) ?? ""
        }
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
}

example(of: "mapping key paths") {
    // 1
    let publisher = PassthroughSubject<Coordinate, Never>()
    
    // 2
    publisher
    // 3
        .map(\.x, \.y)
        .sink(receiveValue: { x, y in
            // 4
            print(
                "The coordinate at (\(x), \(y)) is in quadrant",
                quadrantOf(x: x, y: y)
            )
        })
        .store(in: &subscriptions)
    
    // 5
    publisher.send(Coordinate(x: 10, y: -8))
    publisher.send(Coordinate(x: 0, y: 5))
}

example(of: "tryMap") {
    // 1
    Just("Directory name that does not exist")
    // 2
        .tryMap { try FileManager.default.contentsOfDirectory(atPath: $0) }
    // 3
        .sink(receiveCompletion: { print($0) },
              receiveValue: { print($0) })
        .store(in: &subscriptions)
}

example(of: "flatMap") {
    // 1
    func decode(_ codes: [Int]) -> AnyPublisher<String, Never> {
        // 2
        Just(
            codes
                .compactMap { code in
                    guard (32...255).contains(code) else { return nil }
                    return String(UnicodeScalar(code) ?? " ")
                }
            // 3
                .joined()
        )
        // 4
        .eraseToAnyPublisher()
    }
    
    // 5
    [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33]
        .publisher
        .collect()
    // 6
        .flatMap(decode)
    // 7
        .sink(receiveValue: { print($0) })
        .store(in: &subscriptions)
}

example(of: "replaceNil") {
    // 1
    ["A", nil, "C"].publisher
        .eraseToAnyPublisher()
        .replaceNil(with: "-") // 2
        .sink(receiveValue: { print($0) }) // 3
        .store(in: &subscriptions)
}

example(of: "replaceEmpty(with:)") {
    // 1
    let empty = Empty<Int, Never>()
    
    // 2
    empty
        .replaceEmpty(with: 1)
        .sink(receiveCompletion: { print($0) },
              receiveValue: { print($0) })
        .store(in: &subscriptions)
}

example(of: "scan") {
    // 1
    var dailyGainLoss: Int { .random(in: -10...10) }
    
    // 2
    let august2019 = (0..<22)
        .map { _ in dailyGainLoss }
        .publisher
    
    // 3
    august2019
        .scan(50) { latest, current in
            max(0, latest + current)
        }
        .sink(receiveValue: { _ in })
        .store(in: &subscriptions)
}
