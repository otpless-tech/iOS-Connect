//
//  SocketEventData.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 20/03/25.
//

import Foundation

struct SocketEventData: Decodable {
    let eventType: AppEventType
    let eventValue: [String: Any]
    let messageId: String
    let senderId: String

    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case eventValue = "event_value"
        case messageId
        case senderId
    }

    init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        let eventName = (try? container?.decode(String.self, forKey: .eventName)) ?? ""
        self.eventType = AppEventType(rawValue: eventName) ?? .unknown
        self.messageId = (try? container?.decode(String.self, forKey: .messageId)) ?? ""
        self.senderId = (try? container?.decode(String.self, forKey: .senderId)) ?? ""
        self.eventValue = (try? container?.decode([String: JSONValue].self, forKey: .eventValue)) ?? [:]
    }
}


class SocketEventParser {
    static func parseEvent(from jsonArray: [Any]) -> SocketEventData? {
        guard let firstElement = jsonArray.first as? [String: Any] else {
            return nil
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: firstElement, options: []) else {
            return nil
        }

        let decoder = JSONDecoder()
        return (try? decoder.decode(SocketEventData.self, from: jsonData))
    }
}

enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: JSONValue])
    case array([JSONValue])
    case null
    
    var value: Any? {
          switch self {
          case .string(let value): return value
          case .int(let value): return value
          case .double(let value): return value
          case .bool(let value): return value
          case .dictionary(let value): return value.mapValues { $0.value }
          case .array(let value): return value.map { $0.value }
          case .null:
              return nil
          }
      }

    init(from decoder: Decoder) {
        let container = try? decoder.singleValueContainer()

        if let value = try? container?.decode(String.self) {
            self = .string(value)
        } else if let value = try? container?.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container?.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container?.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container?.decode([String: JSONValue].self) {
            self = .dictionary(value)
        } else if let value = try? container?.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }
}
