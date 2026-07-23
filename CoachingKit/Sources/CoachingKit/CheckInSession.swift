import Foundation
import SwiftData

@Model
public final class CheckInSession {
    public var date: Date
    public var mouthCornerLeft: Double
    public var mouthCornerRight: Double
    public var browTension: Double
    public var lightingQuality: Double
    public var deviceAngleOK: Bool
    public var scoreDelta: Double

    // 세션 통계 (2026-07 데이터 수집 확장). 구버전 레코드는 nil.
    public var smileMean: Double?
    public var smileMax: Double?
    public var smileStability: Double?
    public var smileAsymmetry: Double?
    public var duchenneScore: Double?
    /// 기분 이모지. 미선택 시 nil.
    public var mood: String?
    /// CheckInPayload JSON. 스키마는 payloadVersion으로 구분한다.
    public var payload: Data?
    public var payloadVersion: Int = 1

    public init(
        date: Date,
        mouthCornerLeft: Double,
        mouthCornerRight: Double,
        browTension: Double,
        lightingQuality: Double,
        deviceAngleOK: Bool,
        scoreDelta: Double,
        smileMean: Double? = nil,
        smileMax: Double? = nil,
        smileStability: Double? = nil,
        smileAsymmetry: Double? = nil,
        duchenneScore: Double? = nil,
        mood: String? = nil,
        payload: Data? = nil,
        payloadVersion: Int = 1
    ) {
        self.date = date
        self.mouthCornerLeft = mouthCornerLeft
        self.mouthCornerRight = mouthCornerRight
        self.browTension = browTension
        self.lightingQuality = lightingQuality
        self.deviceAngleOK = deviceAngleOK
        self.scoreDelta = scoreDelta
        self.smileMean = smileMean
        self.smileMax = smileMax
        self.smileStability = smileStability
        self.smileAsymmetry = smileAsymmetry
        self.duchenneScore = duchenneScore
        self.mood = mood
        self.payload = payload
        self.payloadVersion = payloadVersion
    }
}
