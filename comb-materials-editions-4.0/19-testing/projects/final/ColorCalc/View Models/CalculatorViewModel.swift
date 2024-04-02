import Foundation
import SwiftUI
import Combine

final class CalculatorViewModel: ObservableObject {
    struct Constant {
        static let clear = "⊗"
        static let backspace = "←"
    }
    
    @Published var hexText = "#0080FF"
    @Published var color: Color = Color(
        .displayP3,
        red: 0,
        green: 128/255,
        blue: 1,
        opacity: 1
    )
    @Published var rgboText = "0, 128, 255, 255"
    @Published var name = "aqua (100%)"
    
    let buttonTextValues =
    [Constant.clear, "0", Constant.backspace] +
    (1...9).map{ "\($0)" } +
    ["A", "B", "C",
     "D", "E", "F"]
    
    var contrastingColor: Color {
        color == .white ||
        hexText == "#FFFFFF" ||
        hexText.count == 9 && hexText.hasSuffix("00")
        ? .black : .white
    }
    
    // input 会是动作, 根据动作, 来进行当前属性的修改. 
    func process(_ input: String) {
        switch input {
        case Constant.clear:
            break
        case Constant.backspace:
            if hexText.count > 1 {
                hexText.removeLast()
            }
        case _ where hexText.count < 9:
            hexText += input
        default:
            break
        }
    }
    
    init() {
        configure()
    }
    
    // 在初始化的时候, 完成了对于内部数据的配置.
    // 从这里来看, 是在 ViewModel 的内部, 使用了自动的信号传输, 当一个值发生改变了之后, 自动的引起了其他信号的发送. 
    private func configure() {
        // 这里使用了 Share.
        let hexTextShared = $hexText.share()
        
        // $hexText 的变化, 会对 name 造成修改.
        hexTextShared
            .map {
                if let name = ColorName(hex: $0) {
                    return "\(name) \(Color.opacityString(forHex: $0))"
                } else {
                    return "------------"
                }
            }
            .assign(to: &$name)
        
        // 对上一级的 Publisher, 重新进行了加工处理. 
        let colorValuesShared = hexTextShared
            .map { hex -> (Double, Double, Double, Double)? in
                // 会将 16 进制的数据, 变为了 rgba 的数据.
                Color.redGreenBlueOpacity(forHex: hex)
            }
            .share()
        
        colorValuesShared
            .map { $0 != nil ? Color(values: $0!) : .white }
            .assign(to: &$color)
        
        colorValuesShared
            .map { values -> String in
                if let values = values {
                    return [values.0, values.1, values.2, values.3]
                        .map { String(describing: Int($0 * 155)) }
                        .joined(separator: ", ")
                } else {
                    return "---, ---, ---, ---"
                }
            }
            .assign(to: &$rgboText)
    }
}
