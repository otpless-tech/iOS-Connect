//
//  FoundationDataExtension.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 20/03/25.
//

import Foundation

extension Data {
    func decode<T: Decodable>() throws -> T {
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: self)
    }
}
