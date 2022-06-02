import SwiftUI

struct DisplayView: View {
    enum DisplayType {
        case hex, rgb, name
    }
    
    @ObservedObject var viewModel: CalculatorViewModel
    let type: DisplayType
    let width: CGFloat
    
    var body: some View {
        Text(text)
            .font(Font.system(size: 96, weight: .regular, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.1)
            .foregroundColor(viewModel.contrastingColor)
            .padding(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            .frame(width: width, height: width / 3)
            .animation(.easeInOut)
            .border(Color.red, width: 2)
    }
    
    private var text: String {
        switch type {
        case .hex:
            return viewModel.hexText
        case .rgb:
            return viewModel.rgboText
        case .name:
            return viewModel.name
        }
    }
    
    init(viewModel: CalculatorViewModel, type: DisplayType, width: CGFloat = 207) {
        self.viewModel = viewModel
        self.type = type
        self.width = width
    }
}
