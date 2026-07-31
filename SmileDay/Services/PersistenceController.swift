import Foundation
import SwiftData
import CoachingKit

/// 앱 하나뿐인 SwiftData 컨테이너.
///
/// 뷰 계층의 `.modelContainer(_:)`만으로는 부족해서 여기로 뺐다. 잠금화면 알림의 "웃었어요"는
/// 화면을 열지 않고 기록하는데, 그때 iOS는 앱을 **백그라운드로만** 깨운다 — `WindowGroup`의 body가
/// 만들어지지 않으므로 environment로 내려주는 컨테이너에 닿을 방법이 없다.
/// `AppDelegate`와 `SmileDayApp`이 같은 저장소를 보게 하려면 뷰 밖에 있어야 한다.
///
/// 실패를 `Result`로 들고 있는 것은 의도다. 여기서 크래시하면 저장소를 못 여는 사용자가 앱을
/// 아예 못 쓴다 — 화면 쪽은 `AppStartupFailureView`로 안내하고, 알림 액션 쪽은 조용히 넘긴다.
enum PersistenceController {
    /// `static let`이라 처음 읽는 쪽에서 한 번만 만들어진다 — 백그라운드 실행이 먼저여도 같다.
    static let shared: Result<ModelContainer, Error> = Result {
        let schema = PersistenceSchema.schema
        let configuration = ModelConfiguration(schema: schema)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
