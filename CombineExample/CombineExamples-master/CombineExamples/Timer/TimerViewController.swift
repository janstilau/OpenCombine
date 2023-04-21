//
//  TimerViewController.swift
//  CombineExamples
//
//  Created by Pawel Krawiec on 19/06/2019.
//  Copyright © 2019 tailec. All rights reserved.
//

import UIKit
import Combine

// 应该还是要有一个 ViewModel 的. 这里讲所有的事情都集合到一起了. 
class TimerViewController: UIViewController {
    
    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var tableView: UITableView! {
        didSet { tableView.dataSource = self }
    }
    
    // 这是一个类似 @State 的存在, 它的责任是 ViewState 的数据表示.
    @Published private var currentTime: String = ""
    
    private var laps = [String]()
    private var cancellableBag = Set<AnyCancellable>()
    
    deinit {
        print("TimerViewController Deinited")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Timer.publish(every: 0.1, on: .main, in: .default) // 产生一个 connectable 对象.
            .autoconnect() // 使用 connectable 产生一个代理类, 在 receive subscriber 的时候, 可以自动 connect
            .scan(0, { (acc, _ ) in return acc + 1 })
            .map { $0.timeInterval }
            .replaceError(with: "") // 这里为什么要 replace. 为的是后面使用 assign 这种方式.
            .eraseToAnyPublisher()
            .assign(to: \.currentTime, on: self)
            .store(in: &cancellableBag)
        
        $currentTime
            .sink { value in
                self.timerLabel.text = value
            }
            .store(in: &cancellableBag)
        
        splitButtonTaps
        // 每次, 都发送新的 Publisher
        // 通过 map 生成 Publisher + switchToLatest 实现了之前请求 cancel 的效果.
            .map { [weak self] _ -> AnyPublisher<String, Never> in
                guard let strongSelf = self else {
                    return Empty().eraseToAnyPublisher()
                }
                return Just(strongSelf.currentTime)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .scan([String]()) { (acc, new) -> [String] in
                return acc + [new]
            }
            .eraseToAnyPublisher()
            .sink { [weak self] laps in
                guard let strongSelf = self else { return }
                strongSelf.laps = laps
                strongSelf.tableView.reloadData()
            }
            .store(in: &cancellableBag)
    }
    
    private let splitButtonTaps = PassthroughSubject<Void, Never>()
    
    @IBAction func splitButtonDidTap(_ sender: UIButton) {
        // Button 没有直接 whenOn 这样的一个 Publisher, 见到的都是第三方自定义的库.
        // 所以, 还是使用 @objc 这种方式, 进行回调的管理, 在里面使用 Object 这种方式, 进行实际的信号发送.
        splitButtonTaps.send()
    }
}

extension TimerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return laps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell =  tableView.dequeueReusableCell(withIdentifier: "cell") else {
            return UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        cell.textLabel?.text = laps[indexPath.row]
        return cell
    }
}

fileprivate extension Int {
    var timeInterval: String {
        String(format: "%0.2d:%0.2d.%0.1d",
               arguments: [(self / 600) % 600, (self % 600 ) / 10, self % 10])
    }
}
