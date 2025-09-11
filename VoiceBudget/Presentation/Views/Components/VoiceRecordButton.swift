import SwiftUI
import AVFoundation

struct VoiceRecordButton: View {
    @Binding var isRecording: Bool
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            if isRecording {
                onStopRecording()
            } else {
                onStartRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(isRecording ? animationScale : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecording)
                
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            if isRecording {
                animationScale = 1.2
            }
        }
        .onChange(of: isRecording) { newValue in
            animationScale = newValue ? 1.2 : 1.0
        }
    }
}

struct PulseView: View {
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .stroke(Color.red.opacity(0.3), lineWidth: 4)
            .frame(width: 100, height: 100)
            .scaleEffect(pulse ? 1.5 : 1.0)
            .opacity(pulse ? 0 : 1)
            .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false), value: pulse)
            .onAppear {
                pulse = true
            }
    }
}

#Preview {
    VoiceRecordButton(
        isRecording: .constant(false),
        onStartRecording: {},
        onStopRecording: {}
    )
}