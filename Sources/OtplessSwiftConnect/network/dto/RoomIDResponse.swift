//
//  APIResponse.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

struct RoomIDResponse: Codable {
    let status: Int
    let data: RoomData
    let timestamp: String
}

struct RoomData: Codable {
    let roomId: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        roomId = try container.decode(String.self, forKey: .roomId)
    }
    
    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
    }
}
