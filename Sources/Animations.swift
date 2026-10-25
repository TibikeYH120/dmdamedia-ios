import SwiftUI

// ---- Mikrointerakció: megnyomásra finom skála ----
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.955 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ---- Lebegő fénygömbök (háttér) ----
struct AppBackground: View {
    @State private var float = false
    var body: some View {
        ZStack {
            Color(red: 0.043, green: 0.059, blue: 0.102)
            Circle()
                .fill(
                    RadialGradient(colors: [Color(red: 0.545, green: 0.361, blue: 0.965).opacity(0.34), .clear],
                                   center: .center, startRadius: 4, endRadius: 240)
                )
                .frame(width: 420, height: 420)
                .offset(x: float ? -120 : -160, y: float ? -190 : -230)
                .animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: float)
            Circle()
                .fill(
                    RadialGradient(colors: [Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.26), .clear],
                                   center: .center, startRadius: 4, endRadius: 210)
                )
                .frame(width: 380, height: 380)
                .offset(x: float ? 150 : 120, y: float ? 240 : 280)
                .animation(.easeInOut(duration: 11).repeatForever(autoreverses: true), value: float)
        }
        .onAppear { float = true }
    }
}

// ---- Shimmer / skeleton ----
struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.10), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.4)
                    .offset(x: phase * geo.size.width * 1.6)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.35).repeatForever(autoreverses: false)) {
                    phase = 1.2
                }
            }
    }
}

extension View {
    func shimmer() -> some View { modifier(Shimmer()) }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .frame(height: 168)
                .shimmer()
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(height: 11)
                .padding(.horizontal, 2)
                .shimmer()
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.05))
                .frame(width: 60, height: 10)
                .padding(.horizontal, 2)
                .shimmer()
        }
    }
}

struct SkeletonGrid: View {
    let columns = [GridItem(.adaptive(minimum: 112), spacing: 12)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(0..<12, id: \.self) { _ in SkeletonCard() }
        }
        .padding(14)
    }
}

// ---- Kártya belépési átmenet ----
extension AnyTransition {
    static var cardIn: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.93).combined(with: .offset(y: 18))),
            removal: .opacity
        )
    }
}

// ---- Betöltő (pulzáló szöveggel) ----
struct LoadingView: View {
    var text = "Betöltés..."
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 4)
                    .frame(width: 46, height: 46)
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(
                        AngularGradient(colors: [Color(red: 0.545, green: 0.361, blue: 0.965),
                                                 Color(red: 0.133, green: 0.827, blue: 0.933)],
                                        center: .center),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 46, height: 46)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                    .animation(.linear(duration: 0.95).repeatForever(autoreverses: false), value: pulse)
            }
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(pulse ? 0.75 : 0.45))
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}
