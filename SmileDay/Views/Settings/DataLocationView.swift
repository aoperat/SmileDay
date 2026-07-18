import SwiftUI

struct DataLocationView: View {
    var body: some View {
        List {
            Section {
                Label("모든 데이터는 이 기기에만 저장됩니다", systemImage: "iphone")
                Label("얼굴 측정값·기록은 외부 서버로 전송되지 않습니다", systemImage: "lock.shield")
                Label("앱을 삭제하면 모든 데이터가 함께 삭제됩니다", systemImage: "trash")
            } footer: {
                Text("이 앱은 카메라로 측정한 얼굴 표정 데이터를 기기 내부 저장공간(SwiftData)에만 보관합니다.")
            }
        }
        .navigationTitle("데이터 저장 위치")
    }
}
