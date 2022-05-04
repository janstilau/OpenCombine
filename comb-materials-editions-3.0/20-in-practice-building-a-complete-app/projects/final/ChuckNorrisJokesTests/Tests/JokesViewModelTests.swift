import XCTest
import Combine
import SwiftUI
@testable import ChuckNorrisJokesModel

final class JokesViewModelTests: XCTestCase {
    
    private lazy var testJoke = self.testJoke(forResource: "TestJoke")
    private lazy var error = URLError(.badServerResponse)
    private var subscriptions = Set<AnyCancellable>()
    
    override func tearDown() {
        subscriptions = []
    }
    
    private func testJoke(forResource resource: String) -> (data: Data, value: Joke) {
        let bundle = Bundle(for: type(of: self))
        
        guard let url = bundle.url(forResource: resource, withExtension: "json"),
              let  data = try? Data(contentsOf: url),
              let joke = try? JSONDecoder().decode(Joke.self, from: data)
        else { fatalError("Failed to load \(resource)") }
        
        return (data, joke)
    }
    
    func test_createJokesWithSampleJokeData() {
        // Given
        guard let url = Bundle.main.url(forResource: "SampleJoke", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return XCTFail("SampleJoke file missing or data is corrupted") }
        
        let sampleJoke: Joke
        
        // When
        do {
            sampleJoke = try JSONDecoder().decode(Joke.self, from: data)
        } catch {
            return XCTFail(error.localizedDescription)
        }
        
        // Then
        XCTAssert(sampleJoke.categories.count == 1, "Sample joke categories.count was expected to be 1 but was \(sampleJoke.categories.count)")
        XCTAssert(sampleJoke.value == "Chuck Norris writes code that optimizes itself.", "First sample joke was expected to be \"Chuck Norris writes code that optimizes itself.\" but was \"\(sampleJoke.value)\"")
    }
    
    func test_backgroundColorFor50TranslationPercentIsGreen() {
        // Given
        
        // When
        
        // Then
        
    }
    
    func test_decisionStateFor60TranslationPercentIsLiked() {
        // Given
        
        // When
        
        // Then
        
    }
    
    func test_decisionStateFor59TranslationPercentIsUndecided() {
        // Given
        
        // When
        
        // Then
        
    }
    
    func test_fetchJokeSucceeds() {
        // Given
        
        // When
        
        // Then
        
    }
    
    func test_fetchJokeReceivesErrorJoke() {
        // Given
        
        // When
        
        // Then
        
    }
}
