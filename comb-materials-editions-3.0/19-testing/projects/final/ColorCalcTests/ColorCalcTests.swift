import XCTest
import Combine
import SwiftUI
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
        viewModel.process(CalculatorViewModel.Constant.backspace)
        
        // Then
        // 4
        XCTAssert(
            result == expected,
            "Hex was expected to be \(expected) but was \(result)"
        )
    }
    
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
