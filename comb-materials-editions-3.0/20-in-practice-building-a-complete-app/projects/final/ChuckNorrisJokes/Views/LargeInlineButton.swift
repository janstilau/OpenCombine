import SwiftUI

struct LargeInlineButton: View {
    let title: String
    let color = Color.secondary
    let action: () -> Void
    
    var body: some View {
        Button(title, action: self.action)
            .scaleEffect(0.8)
            .font(.title)
            .foregroundColor(color)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 60, alignment: .center)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 2))
            .padding(.leading, 20)
            .padding(.trailing, 20)
    }
}

#if DEBUG
struct LargeInlineButton_Previews: PreviewProvider {
    static var previews: some View {
        LargeInlineButton(title: "Toggle Language", action: {})
            .previewLayout(.sizeThatFits)
    }
}
#endif
