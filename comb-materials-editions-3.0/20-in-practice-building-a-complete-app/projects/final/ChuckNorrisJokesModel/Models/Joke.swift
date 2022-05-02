
import Foundation

public struct Joke: Codable, Identifiable, Equatable {
    enum CodingKeys: String, CodingKey {
        case id, value, categories
    }
    
    static let error = Joke(
        id: "error",
        value: "Houston we have a problem — no joke!\n\nCheck your Internet connection and try again.",
        categories: []
    )
    
    public static let starter: Joke = {
        guard let url = Bundle.main.url(forResource: "SampleJoke", withExtension: "json"),
              var data = try? Data(contentsOf: url),
              let joke = try? JSONDecoder().decode(Joke.self, from: data)
        else { return error }
        
        return Joke(
            id: joke.id,
            value: joke.value,
            categories: joke.categories
        )
    }()
    
    public let id: String
    public let value: String
    public let categories: [String]
    
    public init(id: String, value: String, categories: [String]) {
        self.id = id
        self.value = value
        self.categories = categories
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        value = try container.decode(String.self, forKey: .value)
        categories = try container.decode([String].self, forKey: .categories)
    }
}
