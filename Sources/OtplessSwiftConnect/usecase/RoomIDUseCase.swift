//
//  RoomIDUseCase.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class RoomIDUseCase {
    private let apiRepository: ApiRepository
    
    init (apiRepository: ApiRepository) {
        self.apiRepository = apiRepository
    }
    
    func invoke(token: String) async -> String? {
        return await apiRepository.getRoomId(headers: [
            "token": token
        ])
    }
}
