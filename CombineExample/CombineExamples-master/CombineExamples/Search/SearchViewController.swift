//
//  SearchViewController.swift
//  CombineExamples
//
//  Created by Pawel Krawiec on 19/06/2019.
//  Copyright © 2019 tailec. All rights reserved.
//

import UIKit
import Combine

class SearchViewController: UIViewController {
    
    @IBOutlet weak var queryTextField: UITextField!
    @IBOutlet weak var tableView: UITableView! {
        didSet { tableView.dataSource = self }
    }
    
    private var repos = [Repo]()
    private var cancellableBag = Set<AnyCancellable>()
    
    @Published private var query: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 在 ViewDidLoad 中, 进行信号的后续事件的绑定.
        $query
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .removeDuplicates()
            .flatMapLatest { query -> AnyPublisher<[Repo], Never> in
                guard query.count >= 3 else {
                    return Just([]).eraseToAnyPublisher()
                }
                return API().search(with: query)
                    .retry(3)
                    .eraseToAnyPublisher()
            }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
            .sink { [weak self] repos in
                guard let strongSelf = self else { return }
                strongSelf.repos = repos
                strongSelf.tableView.reloadData()
            }
            .store(in: &cancellableBag)
    }
    
    
    @IBAction func queryDidChange(_ sender: UITextField) {
        // 在 Target-Action 里面, 进行信号的发送.
        // 将所有的修改, 链接到了 Subject 的信号处理里面.
        // 因为, Combine 里面, 其实没有对于 Cocoa 的各种事件的处理, 所以每次想要让 Cocoa 的事件触发, 其实是使用了 Subject 的 send 函数.
        // @Published 中, 藏了一个 PublishedSubject 对象, 每次修改之后, 就是该对象的 send 方法的触发.
        // 在没有引入第三方库的时候, 使用 Subject 来桥接 Cocoa 的各种 UI 事件, 是最常见的方式. 
        query = sender.text ?? ""
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return repos.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell =  tableView.dequeueReusableCell(withIdentifier: "cell") else {
            return UITableViewCell(style: .default, reuseIdentifier: "cell")
        }
        cell.textLabel?.text = repos[indexPath.row].name
        return cell
    }    
}

fileprivate class API {
    func search(with query: String) -> AnyPublisher<[Repo], Never> {
        URLSession.shared.dataTaskPublisher(for: URLRequest(url: URL(string: "https://api.github.com/search/repositories?q=\(query)")!))
            .map { $0.data }
            .decode(type: SearchResponse.self, decoder: JSONDecoder())
            .map { $0.items }
            .replaceError(with: [])
            .eraseToAnyPublisher()
    }
}

fileprivate struct SearchResponse: Decodable {
    let items: [Repo]
}

fileprivate struct Repo: Decodable, Hashable {
    let name: String
}
