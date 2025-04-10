//
//  RoomRequestTokenUseCase.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class RoomTokenUseCase {
    private let apiRepository: ApiRepository
    
    init (apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }
    
    func invoke(appId: String, secret: String) async -> String? {
        let roomTokenRequestBody = RoomTokenRequestBody(appId: appId)
        return await apiRepository.getRoomRequestToken(body: roomTokenRequestBody.toDict(), headers: [
            "secret": secret
        ])
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
            print("Error converting to dictionary: \(error)")
        }
        return [:]
    }
}
