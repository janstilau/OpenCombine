import Foundation
import SwiftUI
import Combine

final class CalculatorViewModel: ObservableObject {
    struct Constant {
        static let clear = "⊗"
        static let backspace = "←"
    }
    
    @Published
    var hexText = "#0080FF"
    
    /*
     ViewModel 中, 有些信号, 是基础信号, 而有些信号是 View 信号.
     基础信号的发出, 会导致整个 Model 其他信号的发射. 这也是 ViewModel 的责任之一, 暴露出 View 直接可以使用的信号.
     
     在 ViewModel 的 Logic 里面, 有义务进行相关 View 信号的 Publisher 的构建. 这些 Publisher 是不可以改变的, 就是当做 View 的绑定器存在的.
     将这层差别理清, 是构建可管理的 ViewModel 的基础.
     */
    
    @Published
    private(set) var color: Color = Color(
        .displayP3,
        red: 0,
        green: 128/255,
        blue: 1,
        opacity: 1
    )
    @Published
    private(set) var rgboText = "0, 128, 255, 255"
    @Published
    private(set) var name = "aqua (100%)"
    
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
    
    func process(_ input: String) {
        switch input {
        case Constant.clear:
            // 这里没操作.
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
        bindingSignals()
    }
    
    private func bindingSignals() {
        // $hexText 的信号发送, 会引起后续的各种处理.
        // 在 ViewModel 内部, 进行了信号的绑定机制.
        // 这应该是一个满通用的设计思路.
        
        
        let hexTextShared = $hexText.share()
        
        hexTextShared
            .map {
                if let name = ColorName(hex: $0) {
                    return "\(name) \(Color.opacityString(forHex: $0))"
                } else {
                    return "------------"
                }
            }
            .assign(to: &$name)
        
        let colorValuesShared = hexTextShared
            .map { hex -> (Double, Double, Double, Double)? in
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
