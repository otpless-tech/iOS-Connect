//
//  RoomIDUseCase.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class RoomIDUseCase {
    private let apiRepository: ApiRepository
    private var retryCount: Int = 0
    
    init (apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }
    
    func invoke(token: String, isRetry: Bool) async -> String? {
        if !isRetry {
            retryCount = 0
        }
        
        if retryCount >= 2 {
            return nil
        }
        
        if let roomId = await apiRepository.getRoomId(headers: [
            "token": token
        ]) {
            return roomId
        }
        
        retryCount += 1
        return await invoke(token: token, isRetry: true)
    }
}

