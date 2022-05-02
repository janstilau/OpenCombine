import SwiftUI
import ChuckNorrisJokesModel

struct SavedJokesView: View {
    var body: some View {
        VStack {
            NavigationView {
                List {
                    ForEach(jokes, id: \.self) { joke in
                        // 1
                        Text(joke.value ?? "N/A")
                    }
                    .onDelete { indices in
                        // 2
                        self.jokes.delete(
                            at: indices,
                            inViewContext: self.viewContext
                        )
                    }
                }
                .navigationBarTitle("Saved Jokes")
            }
        }
    }
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(
            keyPath: \JokeManagedObject.value,
            ascending: true
        )],
        animation: .default
    ) private var jokes: FetchedResults<JokeManagedObject>
}

struct SavedJokesView_Previews: PreviewProvider {
    static var previews: some View {
        SavedJokesView()
    }
}
