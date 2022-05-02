import Combine

// 使用, Combine 内置的 Publisher 来完成效果.
extension Publisher {
    // 其实就是 compactMap.
    // 1
    // public struct CompactMap<Upstream, Output>
    // CompactMap 的类型参数, 是上面两种类型.
    // 这里的解读是, 返回的是一个 CompactMap 类型的对象, Output 的 Type 是 T, 而当前的 Publisher 的 Output 的 Type 是 Optional<T>
    // 这里, Output == Optional<T> 是限制的, 当前的 Publisher 的 Output 的类型. 
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


