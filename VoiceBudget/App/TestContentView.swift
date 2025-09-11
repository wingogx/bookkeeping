import SwiftUI

/// 测试用的简化ContentView
struct TestContentView: View {
    @State private var buttonPressed = false
    @State private var recordingState = "待机"
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                Text("VoiceBudget 测试")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("状态: \(recordingState)")
                    .font(.headline)
                    .foregroundColor(recordingState == "录音中" ? .red : .blue)
                
                Button(action: {
                    print("🔥 按钮被点击了! 当前时间: \(Date())")
                    
                    // 改变状态
                    recordingState = "录音中"
                    buttonPressed = true
                    showAlert = true
                    
                    // 2秒后恢复
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        recordingState = "完成"
                        buttonPressed = false
                    }
                    
                }) {
                    HStack {
                        Image(systemName: buttonPressed ? "mic.circle.fill" : "mic.fill")
                            .font(.title)
                        Text(buttonPressed ? "录音中..." : "开始记账")
                            .font(.headline)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 15)
                    .background(buttonPressed ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
                }
                
                Text("点击次数统计会在控制台显示")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            .padding()
            .navigationTitle("测试页面")
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("按钮响应成功!"),
                    message: Text("功能正常工作\n请查看Xcode控制台日志"),
                    dismissButton: .default(Text("好的"))
                )
            }
        }
    }
}

#Preview {
    TestContentView()
}