import UIKit
import Combine

class StoriesTableViewController: UITableViewController {
    // 每次, Stories 的改变, 都会引起 UI 的改变.
    var stories = [Story]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    private let api = API()
    private var subscriptions = [AnyCancellable]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 1.0, alpha: 0.9)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 响应式, 交互的方式变了. 不再是通过传输 Block 的方式, 而是使用了统一的 Publisher 的结构.
        api.stories()
            .receive(on: DispatchQueue.main)
        // 如果, 出错了, 那么就不进行后续的响应节点的触发了. 
            .catch { _ in Empty() }
            .assign(to: \.stories, on: self)
            .store(in: &subscriptions)
    }
    
    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stories.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let story = stories[indexPath.row]
        
        cell.textLabel!.text = story.title
        cell.textLabel!.textColor = UIColor.orange
        cell.detailTextLabel!.text = "By \(story.by)"
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
