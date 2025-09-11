// 测试按钮反馈的简化版本
import SwiftUI

struct TestButtonView: View {
    @State private var isPressed = false
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("按钮测试")
                .font(.title)
            
            // 简单的颜色变化测试
            Button(action: {
                print("✅ 按钮被点击了！")
                isPressed.toggle()
                showAlert = true
            }) {
                Text(isPressed ? "已点击!" : "点击我")
                    .padding()
                    .background(isPressed ? Color.green : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // 显示状态
            Text("状态: \(isPressed ? "已点击" : "未点击")")
                .foregroundColor(isPressed ? .green : .gray)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("成功!"),
                message: Text("按钮点击功能正常工作"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}