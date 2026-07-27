import SwiftUI

struct DataLocationView: View {
    var body: some View {
        List {
            Section {
                Label("사진과 영상은 저장하지 않습니다", systemImage: "camera")
                Label("모든 기록은 이 기기에만 저장됩니다", systemImage: "iphone")
                Label("외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
                Label("앱을 삭제하면 모든 기록이 함께 삭제됩니다", systemImage: "trash")
            } footer: {
                Text("카메라는 얼굴이 잘 잡혔는지 확인하는 데만 씁니다. 미소 시간 기록과 기분·한 줄 기록은 기기 내부 저장공간(SwiftData)에만 보관합니다.")
            }
        }
        .navigationTitle("데이터 저장 위치")
    }
}
