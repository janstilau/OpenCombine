
import XCTest
import Combine
import SwiftUI
// 通过在测试文件中使用 @testable import，我们可以在测试中访问被测试模块的 internal 级别的实现，而无需将这些实现声明为 public
@testable import ColorCalc

class ColorCalcTests: XCTestCase {
    var viewModel: CalculatorViewModel!
    var subscriptions = Set<AnyCancellable>()
    
    override func setUp() {
        viewModel = CalculatorViewModel()
    }
    
    override func tearDown() {
        subscriptions = []
    }
    
    func test_correctNameReceived() {
        // Given
        // 1
        let expected = "rwGreen 66%"
        var result = ""
        
        // 2
        viewModel.$name
            .sink(receiveValue: { result = $0 })
            .store(in: &subscriptions)
        
        // When
        // 3
        viewModel.hexText = "006636AA"
        // hexText 的出发, 会引起 name 的变化, 而 name 的变化, 会引起了 result 的变化.
        
        // Then
        // 4
        XCTAssert(
            result == expected,
            "Name expected to be \(expected) but was \(result)"
        )
    }
    
    func test_processBackspaceDeletesLastCharacter() {
        // Given
        // 1
        let expected = "#0080F"
        var result = ""
        
        // 2
        viewModel.$hexText
            .dropFirst()
            .sink(receiveValue: { result = $0 })
            .store(in: &subscriptions)
        
        // When
        // 3
        // ViewAction, 触发了 ModelAction, 然后 ModelAction 里面的状态修改, 触发了信号发送, UI 层进行了信号的处理.
        // 这里就是, var hexText = "#0080FF" 这是默认值, 然后进行回退, 变为了  0080F, 发送了信号, 导致了 result 的变化.
        viewModel.process(CalculatorViewModel.Constant.backspace)
        
        // Then
        // 4
        XCTAssert(
            result == expected,
            "Hex was expected to be \(expected) but was \(result)"
        )
    }
    
    // 从这里来看,  VM 的测试, 都是通过信号的发送触发的.
    // 最后测试的, 都是利用相等性进行的判断.
    func test_correctColorReceived() {
        // Given
        let expected = Color(hex: ColorName.rwGreen.rawValue)!
        var result: Color = .clear
        
        viewModel.$color
            .sink(receiveValue: { result = $0 })
            .store(in: &subscriptions)
        
        // When
        viewModel.hexText = ColorName.rwGreen.rawValue
        
        // Then
        XCTAssert(
            result == expected,
            "Color expected to be \(expected) but was \(result)"
        )
    }
    
    func test_processBackspaceReceivesCorrectColor() {
        // Given
        // 1
        let expected = Color.white
        var result = Color.clear
        
        viewModel.$color
            .sink(receiveValue: { result = $0 })
            .store(in: &subscriptions)
        
        // When
        // 2
        viewModel.process(CalculatorViewModel.Constant.backspace)
        
        // Then
        // 3
        XCTAssert(
            result == expected,
            "Hex was expected to be \(expected) but was \(result)"
        )
    }
    
    func test_whiteColorReceivedForBadData() {
        // Given
        let expected = Color.white
        var result = Color.clear
        
        viewModel.$color
            .sink(receiveValue: { result = $0 })
            .store(in: &subscriptions)
        
        // When
        viewModel.hexText = "abc"
        
        // Then
        XCTAssert(
            result == expected,
            "Color expected to be \(expected) but was \(result)"
        )
    }
}
