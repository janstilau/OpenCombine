import SwiftUI

struct CalculatorButton: View {
    @ObservedObject var viewModel: CalculatorViewModel
    let text: String
    let color: Color
    
    var body: some View {
        Button(action: {
            // View Action 触发 ViewModel 的 IntentAction.
            self.viewModel.process(self.text)
        }) {
            Text(text)
                .font(Font.system(size: 48, weight: .regular, design: .monospaced))
                .foregroundColor(viewModel.contrastingColor)
        }
    }
    
    init(viewModel: CalculatorViewModel, text: String, color: Color = .white) {
        self.text = text
        self.color = color
        self.viewModel = viewModel
    }
}
