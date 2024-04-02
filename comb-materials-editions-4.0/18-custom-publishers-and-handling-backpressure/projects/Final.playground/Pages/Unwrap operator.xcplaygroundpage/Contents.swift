import Combine

extension Publisher {
    // 1
    func unwrap<T>() -> Publishers.CompactMap<Self, T> where Output == Optional<T> {
        // 2
        compactMap { $0 }
    }
}

let values: [Int?] = [1, 2, nil, 3, nil, 4]

values.publisher
    .unwrap()
    .sink {
        print("Received value: \($0)")
    }

