import Foundation

/// 실시간 확인 모드의 신호 세기와 품질 판정.
///
/// 신호는 "웃음의 좋고 나쁨"이 아니라 세션 시작 시 편한 표정 대비 입꼬리가 얼마나
/// 올라왔는지를 0~1로 옮긴 값이다. 좌우 차이로 깎지 않고, 미간·눈가·턱,
/// 감정 추론 값은 쓰지 않는다.
///
/// 화면에는 이 값을 숫자로 보여주지 않는다. `LiveSmileLevel`로 묶어서 단계로만 보여준다.
public enum LiveSmileSignalEvaluator {
    /// 0~1로 펼칠 상대 신호의 폭.
    ///
    /// 제품 기준이 아니라 표시 스케일이다. 실기기 검증에서 얼굴·거리·조명 조건에 맞춰 조정한다.
    public static let displaySpan = 0.45

    /// 카메라를 바라보는 방향에서 이만큼까지는 보고 있는 것으로 친다.
    ///
    /// 넉넉하게 잡았다. 이 각도에서는 반대쪽 입꼬리가 짧아 보여 값이 덜 정확하지만,
    /// 세워둔 기기를 곁눈으로 보며 쓰는 상황에서 아예 인식이 끊기는 쪽이 더 나쁘다.
    /// 정확도보다 인식률을 택한 값이며, 실기기에서 조정한다.
    public static let gazeToleranceDegrees = 40.0

    /// 이 밝기(lux) 아래를 어두움으로 본다.
    public static let darkAmbientIntensity = 300.0

    /// 좌우 입꼬리 평균. 비대칭은 감점 요소가 아니라 그냥 평균으로 들어간다.
    public static func smileMean(_ sample: LiveSmileSample) -> Double {
        let left = clampUnit(sample.mouthSmileLeft)
        let right = clampUnit(sample.mouthSmileRight)
        return (left + right) / 2
    }

    /// 편한 표정 평균 대비 올라온 만큼. 0~1.
    ///
    /// 편한 표정보다 낮으면 0이다 — 음수 신호나 "찡그림 점수"를 만들지 않는다.
    public static func signal(sample: LiveSmileSample, neutralSmileMean: Double) -> Double {
        let relative = smileMean(sample) - clampUnit(neutralSmileMean)
        guard relative > 0 else { return 0 }

        return min(relative / displaySpan, 1)
    }

    /// 카메라를 바라보고 있는지.
    ///
    /// 화면 중앙에 있는지는 보지 않는다. 비켜 앉아도 카메라 쪽을 보면 통과한다.
    public static func isFacingCamera(_ sample: LiveSmileSample) -> Bool {
        abs(sample.gazeOffsetDegrees) <= gazeToleranceDegrees
    }

    /// 밝기 추정값이 있고 임계값 아래일 때만 true.
    ///
    /// 아직 추정값이 없는 상태(nil)를 어두움으로 단정하면 시작하자마자 조명 안내가 뜬다.
    public static func isTooDark(_ sample: LiveSmileSample) -> Bool {
        guard let ambientIntensity = sample.ambientIntensity else { return false }
        return ambientIntensity < darkAmbientIntensity
    }

    private static func clampUnit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

/// 화면에 보여주는 단계.
///
/// 신호 범위를 똑같이 4등분하지 않는다. 아래쪽을 좁게 둬서 편한 표정에서 벗어나는
/// 첫 변화를 바로 알아차리게 하고, 위로 갈수록 넓게 둬서 더 크게 웃으라고 밀지 않는다.
public enum LiveSmileLevel: Int, CaseIterable, Equatable, Sendable {
    case resting
    case starting
    case holding
    case clear

    /// 이 단계가 시작되는 신호 값. 폭은 0.10 / 0.20 / 0.30 / 0.40으로 점점 넓어진다.
    public var lowerBound: Double {
        switch self {
        case .resting: 0
        case .starting: 0.10
        case .holding: 0.30
        case .clear: 0.60
        }
    }

    public static func containing(signal: Double) -> LiveSmileLevel {
        allCases.last { signal >= $0.lowerBound } ?? .resting
    }
}
