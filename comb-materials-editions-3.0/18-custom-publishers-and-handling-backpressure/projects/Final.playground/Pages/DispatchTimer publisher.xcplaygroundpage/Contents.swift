import Foundation
import Combine

// 配置类, 这个类, 帮助生成 Publisher 的实例.
struct DispatchTimerConfiguration {
    // 1
    let queue: DispatchQueue?
    // 2
    let interval: DispatchTimeInterval
    // 3
    let leeway: DispatchTimeInterval
    // 4
    let times: Subscribers.Demand
}

extension Publishers {
    // 惯例 Publihser 实现.
    // 生成 DispatchTimer, 主要是为了收集信息. 在真正的调用 receive 的时候, 才生成对应的 DispatchTimerSubscription 对象.
    // 将 DispatchTimerSubscription 交给后续的 subscriber
    struct DispatchTimer: Publisher {
        // 5
        typealias Output = DispatchTime
        typealias Failure = Never
        
        // 6
        let configuration: DispatchTimerConfiguration
        
        init(configuration: DispatchTimerConfiguration) {
            self.configuration = configuration
        }
        
        // 7
        func receive<S: Subscriber>(subscriber: S)
        where Failure == S.Failure, Output == S.Input {
            // 8
            let subscription = DispatchTimerSubscription(
                // 在这里, 生成了循环引用.
                subscriber: subscriber,
                configuration: configuration
            )
            // 9
            subscriber.receive(subscription: subscription)
        }
    }
}

private final class DispatchTimerSubscription<S: Subscriber>: Subscription
where S.Input == DispatchTime {
    // 10
    // 值的收集.
    let configuration: DispatchTimerConfiguration
    // 11 Demand 管理. 当前的 Publisher 可以产生多少出具.
    // 这个代表着最大的 Timer 可以发出的信号数量.
    var times: Subscribers.Demand
    // 12 Demand 管理, 下游要求多少个数据.
    var requested: Subscribers.Demand = .none
    // 13
    // 真正的 Timer 的实现.
    var source: DispatchSourceTimer? = nil
    // 14
    var subscriber: S?
    
    init(subscriber: S, configuration: DispatchTimerConfiguration) {
        self.configuration = configuration
        self.subscriber = subscriber
        self.times = configuration.times
    }
    
    // 15
    func request(_ demand: Subscribers.Demand) {
        // 16
        guard times > .none else {
            // 17
            // 只有, 当 configure 的初始值直接是 .none 的时候, 才会触发这样的事情.
            // 也就是说, 这个 Publsiher 的使用者, 开始就没打算使用这个定时器.
            subscriber?.receive(completion: .finished)
            return
        }
        
        // 18
        // 在 request(_ demand 内, 根据传递过来的 demand 的值, 来调整当前
        requested += demand
        
        // 19
        // 真正触发, 信号产生的逻辑, 只会触发一次.
        if source == nil, requested > .none {
            // 20
            let source = DispatchSource.makeTimerSource(queue: configuration.queue)
            // 21
            source.schedule(deadline: .now() + configuration.interval,
                            repeating: configuration.interval,
                            leeway: configuration.leeway)
            
            // 22
            source.setEventHandler { [weak self] in
                // 23
                // 这个定时器, 其实一直在触发. 如果下游所需要的 demand 已经没有了, 直接 return, 不会触发下游的 receive 的事件.
                // 在 request Demand 里面, self.requested 会被更新.
                // 通过这个机制, 完成了 Subscription 对于 Demand 的管理.
                guard let self = self,
                      self.requested > .none else { return }
                
                // 24
                self.requested -= .max(1)
                self.times -= .max(1)
                // 25
                _ = self.subscriber?.receive(.now())
                // 26
                if self.times == .none {
                    // 当, 发射完了所有的数据, 主动向下游进行 finished 的发送.
                    self.subscriber?.receive(completion: .finished)
                }
            }
            
            self.source = source
            source.activate()
        }
    }
    
    func cancel() {
        // cancel 的时候, 确保释放自己的资源.
        // 1 内存资源.
        // 2 自己相关的机制资源.
        source = nil
        subscriber = nil
    }
}

// 在 Publishers 添加一个快捷的方法, 作为生成 DispatchTimer 的入口.
// 如果, 是一个 Operator, 那么这个就会添加到了 Publisher 的 extension 中了.
extension Publishers {
    static func timer(queue: DispatchQueue? = nil,
                      interval: DispatchTimeInterval,
                      leeway: DispatchTimeInterval = .nanoseconds(0),
                      times: Subscribers.Demand = .unlimited)
    -> Publishers.DispatchTimer {
        return Publishers.DispatchTimer(
            configuration: .init(queue: queue,
                                 interval: interval,
                                 leeway: leeway,
                                 times: times)
        )
    }
}

// 27
var logger = TimeLogger(sinceOrigin: true)
// 28
let publisher = Publishers.timer(interval: .seconds(1),
                                 times: .max(6))
// 29
let subscription = publisher.sink { time in
    print("Timer emits: \(time)", to: &logger)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
    subscription.cancel()
}

