import SwiftUI
import ChuckNorrisJokesModel

struct JokeView: View {
    var body: some View {
        ZStack {
            NavigationView {
                VStack {
                    Spacer()
                    
                    LargeInlineButton(title: "Show Saved") {
                        self.presentSavedJokes = true
                    }
                    .padding(20)
                }
                .navigationBarTitle("Chuck Norris Jokes")
            }
            .sheet(isPresented: $presentSavedJokes) {
                SavedJokesView()
                    .environment(\.managedObjectContext, self.viewContext)
            }
            
            HStack {
                Circle()
                    .trim(from: 0.5, to: 1)
                    .stroke(Color("Gray"), lineWidth: 4)
                    .frame(width: circleDiameter, height: circleDiameter)
                    .rotationEffect(.degrees(showFetchingJoke ? 0 : -360))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false)
                    )
            }
            .opacity(showFetchingJoke ? 1 : 0)
            
            jokeCardView
                .opacity(showJokeView ? 1 : 0)
                .offset(y: showJokeView ? 0.0 : -bounds.height)
            
            HUDView(imageType: .thumbDown)
                .opacity(viewModel.decisionState == .disliked ? hudOpacity : 0)
                .animation(.easeInOut)
            
            HUDView(imageType: .rofl)
                .opacity(viewModel.decisionState == .liked ? hudOpacity : 0)
                .animation(.easeInOut)
        }
        .onAppear(perform: {
            self.reset()
        })
    }
    
    @ObservedObject private var viewModel = JokesViewModel()
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var showJokeView = false
    @State private var showFetchingJoke = false
    @State private var cardTranslation: CGSize = .zero
    @State private var hudOpacity = 0.5
    @State private var presentSavedJokes = false
    
    private var bounds: CGRect { UIScreen.main.bounds }
    private var translation: Double { Double(cardTranslation.width / bounds.width) }
    private var circleDiameter: CGFloat { bounds.width * 0.9 }
    
    private var jokeCardView: some View {
        JokeCardView(viewModel: viewModel)
            .background(viewModel.backgroundColor)
            .cornerRadius(20)
            .shadow(radius: 10)
            .rotationEffect(rotationAngle)
            .offset(x: cardTranslation.width, y: cardTranslation.height)
            .animation(.spring(response: 0.5, dampingFraction: 0.4, blendDuration: 2))
            .gesture(
                DragGesture()
                    .onChanged { change in
                        self.cardTranslation = change.translation
                        self.updateBackgroundColor()
                    }
                    .onEnded { change in
                        self.updateDecisionStateForChange(change)
                        self.handle(change)
                    }
            )
    }
    
    private var rotationAngle: Angle {
        return Angle(degrees: 75 * translation)
    }
    
    private func updateDecisionStateForChange(_ change: DragGesture.Value) {
        viewModel.updateDecisionStateForTranslation(
            translation,
            andPredictedEndLocationX: change.predictedEndLocation.x,
            inBounds: bounds
        )
    }
    
    private func updateBackgroundColor() {
        viewModel.updateBackgroundColorForTranslation(translation)
    }
    
    private func handle(_ change: DragGesture.Value) {
        // 1
        let decisionState = viewModel.decisionState
        
        switch decisionState {
            // 2
        case .undecided:
            cardTranslation = .zero
            self.viewModel.reset()
        default:
            if decisionState == .liked {
                JokeManagedObject.save(
                    joke: viewModel.joke,
                    inViewContext: viewContext
                )
            }
            
            // 3
            let translation = change.translation
            let offset = (decisionState == .liked ? 2 : -2) * bounds.width
            cardTranslation = CGSize(
                width: translation.width + offset,
                height: translation.height
            )
            showJokeView = false
            
            // 4
            reset()
        }
    }
    
    private func reset() {
        // 各种信号的改版. 
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.showFetchingJoke = true
            self.hudOpacity = 0.5
            self.cardTranslation = .zero
            self.viewModel.reset()
            self.viewModel.fetchJoke()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.showFetchingJoke = false
                self.showJokeView = true
                self.hudOpacity = 0
            }
        }
    }
}
