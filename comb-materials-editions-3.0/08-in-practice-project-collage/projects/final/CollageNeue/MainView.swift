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
          model.add()
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
    .onReceive(model.updateUISubject, perform: updateUI)
  }
  
  func updateUI(photosCount: Int) {
    saveIsEnabled = photosCount > 0 && photosCount % 2 == 0
    clearIsEnabled = photosCount > 0
    addIsEnabled = photosCount < 6
    title = photosCount > 0 ? "\(photosCount) photos" : "Collage Neue"
  }
}
