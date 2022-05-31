import UIKit
import Combine

class StoriesTableViewController: UITableViewController {
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
        
        api.stories()
            .receive(on: DispatchQueue.main)
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
