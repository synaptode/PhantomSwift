#if DEBUG
import SwiftUI

/// A ViewModifier that tracks when a SwiftUI View is re-evaluated.
@available(iOS 13.0, *)
public struct PhantomRenderTracker: ViewModifier {
    let name: String
    
    @State private var flashColor: Color = .clear
    
    public func body(content: Content) -> some View {
        PhantomRenderStore.shared.track(viewName: name, type: .swiftUI)
        
        return content
            .overlay(
                Rectangle()
                    .stroke(flashColor, lineWidth: 2)
                    .animation(.easeOut(duration: 0.5), value: flashColor)
            )
            .onAppear {
                triggerFlash()
            }
    }
    
    private func triggerFlash() {
        flashColor = Color.blue.opacity(0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            flashColor = .clear
        }
    }
}

@available(iOS 13.0, *)
public extension View {
    /// Tracks this view's render cycle in PhantomSwift.
    /// - Parameter name: Friendly name for the view.
    func trackRender(as name: String) -> some View {
        self.modifier(PhantomRenderTracker(name: name))
    }
}
#endif
