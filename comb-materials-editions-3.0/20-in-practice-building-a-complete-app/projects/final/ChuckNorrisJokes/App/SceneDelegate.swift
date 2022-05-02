
import UIKit
import SwiftUI
import Combine
import CoreData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = JokeView()
            .environment(\.managedObjectContext, CoreDataStack.viewContext)
        
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        CoreDataStack.save()
    }
}

// 1
private enum CoreDataStack {
    // 2
    static var viewContext: NSManagedObjectContext = {
        let container = NSPersistentContainer(name: "ChuckNorrisJokes")
        
        container.loadPersistentStores { _, error in
            guard error == nil else {
                fatalError("\(#file), \(#function), \(error!.localizedDescription)")
            }
        }
        
        return container.viewContext
    }()
    
    // 3
    static func save() {
        guard viewContext.hasChanges else { return }
        
        do {
            try viewContext.save()
        } catch {
            fatalError("\(#file), \(#function), \(error.localizedDescription)")
        }
    }
}
