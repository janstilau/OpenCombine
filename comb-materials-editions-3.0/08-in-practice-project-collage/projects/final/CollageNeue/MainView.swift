import SwiftUI
import Combine

struct MainView: View {
  @EnvironmentObject var model: CollageNeueModel
  
  @State private var isDisplayingSavedMessage = false
  
  @State private var lastErrorMessage = "" {
    didSet {
      isDisplayingErrorMessage = true
    }
  }
  @State private var isDisplayingErrorMessage = false
  
  @State private var isDisplayingPhotoPicker = false
  
  @State private(set) var saveIsEnabled = true
  @State private(set) var clearIsEnabled = true
  @State private(set) var addIsEnabled = true
  @State private(set) var title = ""
  
  var body: some View {
    VStack {
      HStack {
        Text(title)
          .font(.title)
          .fontWeight(.bold)
        Spacer()
        
        Button(action: {
          model.addNewImage()
          // isDisplayingPhotoPicker 的变化, 引起了 View 层级的变化, 弹出了添加图片的 VC.
          isDisplayingPhotoPicker = true
        }, label: {
          Text("＋").font(.title)
        })
          .disabled(!addIsEnabled)
      }
      .padding(.bottom)
      .padding(.bottom)
      
      // imagePreview 的变化, 直接影响到了 UI 的变化.
      Image(uiImage: model.imagePreview ?? UIImage())
        .resizable()
        .frame(height: 200, alignment: .center)
        .border(Color.gray, width: 2)
      
      Button(action: model.clear, label: {
        Text("Clear")
          .fontWeight(.bold)
          .frame(maxWidth: .infinity)
      })
        .disabled(!clearIsEnabled)
        .buttonStyle(.bordered)
        .padding(.vertical)
      
      Button(action: model.save, label: {
        Text("Save")
          .fontWeight(.bold)
          .frame(maxWidth: .infinity)
      })
        .disabled(!saveIsEnabled)
        .buttonStyle(.borderedProminent)
      
    }
    .padding()
    /*
     Summary
     Adds a modifier for this view that fires an action when a specific value changes.
     Declaration
     
     func onChange<V>(of value: V, perform action: @escaping (V) -> Void) -> some View where V : Equatable
     Discussion
     
     You can use onChange to trigger a side effect as the result of a value changing, such as an Environment key or a Binding.
     onChange is called on the main thread. Avoid performing long-running tasks on the main thread. If you need to perform a long-running task in response to value changing, you should dispatch to a background queue.
     The new value is passed into the closure. The previous value may be captured by the closure to compare it to the new value. For example, in the following code example, PlayerView passes both the old and new values to the model.
     struct PlayerView: View {
     var episode: Episode
     @State private var playState: PlayState = .paused
     
     var body: some View {
     VStack {
     Text(episode.title)
     Text(episode.showTitle)
     PlayButton(playState: $playState)
     }
     .onChange(of: playState) { [playState] newState in
     model.playStateDidChange(from: playState, to: newState)
     }
     }
     }
     Parameters
     
     value
     The value to check against when determining whether to run the closure.
     action
     A closure to run when the value changes.
     newValue
     The new value that failed the comparison check.
     Returns
     
     A view that fires an action when the specified value changes.
     */
    .onChange(of: model.lastSavedPhotoID, perform: { lastSavedPhotoID in
      isDisplayingSavedMessage = true
    })
    
    .alert("Saved photo with id: \(model.lastSavedPhotoID)", isPresented: $isDisplayingSavedMessage, actions: { })
    .alert(lastErrorMessage, isPresented: $isDisplayingErrorMessage, actions: { })
    .sheet(isPresented: $isDisplayingPhotoPicker, onDismiss: {
      
    }) {
      PhotosView().environmentObject(model)
    }
    
    .onAppear(perform: model.bindMainView)
    // 当, 收到 Model 的 updateUISubject 的时候, 可以指定一个函数.
    // 在 View 里面, 也可以进行函数的定义. 不过, 一般就是在里面, 进行 UI 的更新了.
    .onReceive(model.updateUISubject, perform: updateUI)
  }
  
  // 类似于 UI 的 UpateViews 的思路了.
  func updateUI(photosCount: Int) {
    saveIsEnabled = photosCount > 0 && photosCount % 2 == 0
    clearIsEnabled = photosCount > 0
    addIsEnabled = photosCount < 6
    title = photosCount > 0 ? "\(photosCount) photos" : "Collage Neue"
  }
}
