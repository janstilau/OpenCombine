import SwiftUI
import Combine

struct CalculatorView: View {
    var body: some View {
        VStack {
            Spacer()
            
            DisplayView(viewModel: viewModel, type: .hex, width: bounds.width)
            
            HStack {
                DisplayView(viewModel: viewModel, type: .rgb, width: bounds.width / 2)
                DisplayView(viewModel: viewModel, type: .name, width: bounds.width / 2)
            }
            
            ButtonRows(viewModel: viewModel)
            
            Spacer()
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(viewModel.color)
        .animation(.easeInOut)
        .edgesIgnoringSafeArea(.all)
    }
    
    // View 所挂钩的 ViewModel 类.
    @ObservedObject private var viewModel = CalculatorViewModel()
    private var bounds: CGRect { return UIScreen.main.bounds }
}

struct ButtonRows: View {
    @ObservedObject var viewModel: CalculatorViewModel
    
    var body: some View {
        ForEach(range) { row in
            Spacer()
            ButtonRow(viewModel: self.viewModel, row: row)
            Spacer()
        }
    }
    
    private var range: Range<Int> { 0..<(viewModel.buttonTextValues.count / 3) }
}

struct ButtonRow: View {
    @ObservedObject var viewModel: CalculatorViewModel
    let row: Int
    
    var body: some View {
        HStack {
            Spacer()
            CalculatorButton(viewModel: viewModel, text: buttonTextValues[0 + (3 * row)])
            Spacer()
            CalculatorButton(viewModel: viewModel, text: buttonTextValues[1 + (3 * row)])
            Spacer()
            CalculatorButton(viewModel: viewModel, text: buttonTextValues[2 + (3 * row)])
            Spacer()
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
    
    private var buttonTextValues: [String] { viewModel.buttonTextValues }
}
