import SwiftUI
import Photos
import Combine

// ImagePickerView页面.
struct PhotosView: View {
  @EnvironmentObject var model: CollageNeueModel
  @Environment(\.presentationMode) var presentationMode
  
  let columns: [GridItem] = [.init(.adaptive(minimum: 100, maximum: 200))]
  
  @State private var subscriptions = [AnyCancellable]()
  
  @State private var photos = PHFetchResult<PHAsset>()
  @State private var imageManager = PHCachingImageManager()
  @State private var isDisplayingError = false
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns, spacing: 2) {
          ForEach((0..<photos.count), id: \.self) { index in
            let asset = photos[index]
            let _ = model.enqueueThumbnail(asset: asset)
            
            Button(action: {
              // 每个按钮点击之后, 是调用 ViewModel 的 ViewAction, 来触发 Model 层的数据变化.
              model.selectImage(asset: asset)
            }, label: {
              Image(uiImage: model.thumbnails[asset.localIdentifier] ?? UIImage(named: "IMG_1907")!)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .clipShape(
                  RoundedRectangle(cornerRadius: 5)
                )
                .padding(4)
            })
          }
        }
        .padding()
      }
      .navigationTitle("Photos")
      .toolbar {
        Button("Close", role: .cancel) {
          self.presentationMode.wrappedValue.dismiss()
        }
      }
    }
    .alert("No access to Camera Roll", isPresented: $isDisplayingError, actions: { }, message: {
      Text("You can grant access to Collage Neue from the Settings app")
    })
    .onAppear {
      // Check for Photos access authorization and reload the list if authorized.
      PHPhotoLibrary.fetchAuthorizationStatus { status in
        if status {
          DispatchQueue.main.async {
            self.photos = model.loadPhotos()
          }
        }
      }
      
      model.bindPhotoPicker()
    }
    .onDisappear {
      // 在 ViewDisAppeared 的时候, 触发了 ViewModel 的 Completion 信号.
      // 这里设计的不好, 直接使用 Model 里面的 selectedPhotosSubject 发送 Completion 事件.
      // 在 Model 内部, 根本不知道这里会触发完结事件.
      model.selectedPhotosSubject.send(completion: .finished)
    }
  }
}
