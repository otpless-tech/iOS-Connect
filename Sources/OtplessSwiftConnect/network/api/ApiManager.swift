//
//  ApiManager.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 19/03/25.
//

import Foundation

class ApiManager {
    private let USER_AUTH_BASE_URL = "https://user-auth.otpless.app"
    private let CONNECT_BASE_URL = "https://connect.otpless.app"
    
    func postUserAuth(
        path: String,
        body: [String: Any],
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = constructURL(baseURL: USER_AUTH_BASE_URL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                let errorBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                throw ApiError(
                    message: errorBody["message"] as? String ?? "Unexpected error occurred",
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    responseJson: errorBody
                )
            }
            
            return data
        } catch {
            sendEvent(event: EventConstants.ERROR_API_RESPONSE, extras: ["error": error.localizedDescription])
            if let apiError = error as? ApiError {
                throw apiError
            } else {
                throw ApiError(
                    message: error.localizedDescription,
                    statusCode: 500,
                    responseJson: [
                        "errorCode": "500",
                        "errorMessage": "Something Went Wrong!"
                    ]
                )
            }
        }
    }
    
    func postConnect(
        path: String,
        body: [String: Any]?,
        headers: [String: String] = [:]
    ) async throws -> Data {
        let url = constructURL(baseURL: CONNECT_BASE_URL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                let errorBody = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
                throw ApiError(
                    message: errorBody["message"] as? String ?? "Unexpected error occurred",
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500,
                    responseJson: errorBody
                )
            }
            
            return data
        } catch {
            if let apiError = error as? ApiError {
                throw apiError
            } else {
                throw ApiError(
                    message: error.localizedDescription,
                    statusCode: 500,
                    responseJson: [
                        "errorCode": "500",
                        "errorMessage": "Something Went Wrong!"
                    ]
                )
            }
        }
    }
    
    private func constructURL(baseURL: String, path: String) -> URL {
        var components = URLComponents(string: baseURL)
        components?.path += path
        return components?.url ?? URL(string: baseURL + path)!
    }
}
