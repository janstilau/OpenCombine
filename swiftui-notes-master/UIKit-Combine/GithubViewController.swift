//
//  ViewController.swift
//  UIKit-Combine
//
//  Created by Joseph Heck on 7/7/19.
//  Copyright © 2019 SwiftUI-Notes. All rights reserved.
//

import Combine
import UIKit

class GithubViewController: UIViewController {
    @IBOutlet var github_id_entry: UITextField!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var repositoryCountLabel: UILabel!
    @IBOutlet var githubAvatarImageView: UIImageView!
    
    var repositoryCountSubscriber: AnyCancellable?
    var avatarViewSubscriber: AnyCancellable?
    var usernameSubscriber: AnyCancellable?
    var apiNetworkActivitySubscriber: AnyCancellable?
    
    // username from the github_id_entry field, updated via IBAction
    @Published var username: String = ""
    
    // github user retrieved from the API publisher. As it's updated, it
    // is "wired" to update UI elements
    @Published private var githubUserData: [GithubAPIUser] = []
    
    var myBackgroundQueue: DispatchQueue = .init(label: "myBackgroundQueue")
    let coreLocationProxy = LocationHeadingProxy()
    
    // MARK: - Actions
    
    @IBAction func githubIdChanged(_ sender: UITextField) {
        // 通过 TargetAction 将 信号发送联系到了一起.
        username = sender.text ?? ""
        print("Set username to ", username)
    }
    
    @IBAction func poke(_: Any) {}
    
    // MARK: - lifecycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // Loading 的触发, 和 API 的开始结束绑定在一起了.
        apiNetworkActivitySubscriber = GithubAPI.networkActivityPublisher
            .receive(on: RunLoop.main)
            .sink { doingSomethingNow in
                if doingSomethingNow {
                    self.activityIndicator.startAnimating()
                } else {
                    self.activityIndicator.stopAnimating()
                }
            }
        
        // 这里算是使用到了一些高级的技巧了.,
        usernameSubscriber = $username
            .throttle(for: 0.5, scheduler: myBackgroundQueue, latest: true)
        // ^^ scheduler myBackGroundQueue publishes resulting elements
        // into that queue, resulting on this processing moving off the
        // main runloop.
            .removeDuplicates()
            .print("username pipeline: ") // debugging output for pipeline
            .map { username -> AnyPublisher<[GithubAPIUser], Never> in
                GithubAPI.retrieveGithubUser(username: username)
            }
        // ^^ type returned in the pipeline is a Publisher, so we use
        // switchToLatest to flatten the values out of that
        // pipeline to return down the chain, rather than returning a
        // publisher down the pipeline.
            .switchToLatest() // 上一步触发的网络请求, 在这里会改变.
        // using a sink to get the results from the API search lets us
        // get not only the user, but also any errors attempting to get it.
            .receive(on: RunLoop.main)
        // githubUserData 这里引起了数据的改变.
            .assign(to: \.githubUserData, on: self)
        
        // using .assign() on the other hand (which returns an
        // AnyCancellable) *DOES* require a Failure type of <Never>
        // 网络请求, 引起了数据的改变, 然后这里是数据的改变, 引起了 UI 的改变.
        repositoryCountSubscriber = $githubUserData
            .print("github user data: ")
            .map { userData -> String in
                if let firstUser = userData.first {
                    return String(firstUser.public_repos)
                }
                return "unknown"
            }
            .receive(on: RunLoop.main)
            .assign(to: \.text, on: repositoryCountLabel)
        
        let avatarViewSub = $githubUserData
        // When I first wrote this publisher pipeline, the type I was
        // aiming for was <GithubAPIUser?, Never>, where the value was an
        // optional. The commented out .filter below was to prevent a `nil` // GithubAPIUser object from propagating further and attempting to
        // invoke the dataTaskPublisher which retrieves the avatar image.
        //
        // When I updated the type to be non-optional (<GithubAPIUser?,
        // Never>) the filter expression was no longer needed, but possibly
        // interesting.
        // .filter({ possibleUser -> Bool in
        //     possibleUser != nil
        // })
        // .print("avatar image for user") // debugging output
            .map { userData -> AnyPublisher<UIImage, Never> in
                guard let firstUser = userData.first else {
                    // my placeholder data being returned below is an empty
                    // UIImage() instance, which simply clears the display.
                    // Your use case may be better served with an explicit
                    // placeholder image in the event of this error condition.
                    return Just(UIImage()).eraseToAnyPublisher()
                }
                // 每次当前用户的改变, 都会触发对应的 UI 改变. 
                return URLSession.shared.dataTaskPublisher(for: URL(string: firstUser.avatar_url)!)
                // ^^ this hands back (Data, response) objects
                // 通过了 handleEvents 的副作用, 来触发了 UI 的改变.
                    .handleEvents(receiveSubscription: { _ in
                        DispatchQueue.main.async {
                            self.activityIndicator.startAnimating()
                        }
                    }, receiveCompletion: { _ in
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                        }
                    }, receiveCancel: {
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                        }
                    })
                    .map { $0.data }
                // ^^ pare down to just the Data object
                    .map { UIImage(data: $0)! }
                // ^^ convert Data into a UIImage with its initializer
                    .subscribe(on: self.myBackgroundQueue)
                // ^^ do this work on a background Queue so we don't screw
                // with the UI responsiveness
                    .catch { _ in
                        Just(UIImage())
                    }
                // ^^ deal the failure scenario and return my "replacement"
                // image for when an avatar image either isn't available or
                // fails somewhere in the pipeline here.
                    .eraseToAnyPublisher()
                // ^^ match the return type here to the return type defined
                // in the .map() wrapping this because otherwise the return
                // type would be terribly complex nested set of generics.
            }
            .switchToLatest()
        // ^^ Take the returned publisher that's been passed down the chain
        // and "subscribe it out" to the value within in, and then pass
        // that further down.
            .subscribe(on: myBackgroundQueue)
        // ^^ do the above processing as well on a background Queue rather
        // than potentially impacting the UI responsiveness
            .receive(on: RunLoop.main)
        // ^^ and then switch to receive and process the data on the main
        // queue since we're messing with the UI
            .map { image -> UIImage? in
                image
            }
        // ^^ this converts from the type UIImage to the type UIImage?
        // which is key to making it work correctly with the .assign()
        // operator, which must map the type *exactly*
            .assign(to: \.image, on: githubAvatarImageView)
        
        // convert the .sink to an `AnyCancellable` object that we have
        // referenced from the implied initializers
        avatarViewSubscriber = AnyCancellable(avatarViewSub)
        
        // KVO publisher of UIKit interface element
        _ = repositoryCountLabel.publisher(for: \.text)
            .sink { someValue in
                print("repositoryCountLabel Updated to \(String(describing: someValue))")
            }
    }
}
