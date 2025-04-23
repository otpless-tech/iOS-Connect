//
//  RoomRequestTokenUseCase.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class RoomTokenUseCase {
    private let apiRepository: ApiRepository
    private var retryCount = 0
    
    init (apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }
    
    func invoke(appId: String, secret: String, isRetry: Bool) async -> String? {
        if !isRetry {
            retryCount = 0
        }
        
        if retryCount >= 2 {
            return nil
        }
        
        let roomTokenRequestBody = RoomTokenRequestBody(appId: appId)
        if let token = await apiRepository.getRoomRequestToken(
            body: roomTokenRequestBody.toDict(),
            headers: [
                "secret": secret
            ]
        ) {
            return token
        }
        
        retryCount += 1
        return await invoke(appId: appId, secret: secret, isRetry: true)
    }
}

private struct RoomTokenRequestBody: Codable, Sendable {
    let appId: String
    
    func toDict() -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        do {
            let jsonData = try encoder.encode(self)
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return jsonObject
            }
        } catch {
            Utils.otplessLog("Error converting to dictionary: \(error)")
        }
        return [:]
    }
}

