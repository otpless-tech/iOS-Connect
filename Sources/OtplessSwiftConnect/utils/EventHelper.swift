//
//  EventConstants.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 23/04/25.
//

import Foundation
import Network

func sendEvent(event: EventConstants, extras: [String: String] = [:], token: String = ""){
    do {
        var params = [String: String]()
        params["event_name"] = event.rawValue
        params["platform"] = "iOS-Connect"
        params["sdk_version"] = "1.0.1"
        params["mid"] = OtplessSwiftConnect.shared.appId
        params["event_timestamp"] = Utils.formatCurrentTimeToDateString()
        
        params["tsid"] = DeviceInfoUtils.shared.getTrackingSessionId()
        params["inid"] = DeviceInfoUtils.shared.getInstallationId()
        params["event_id"] = String(OtplessSwiftConnect.shared.getEventCounterAndIncrement())
        
        if !token.isEmpty {
            params["token"] = token
        }
        
        if let eventParamsData = try? JSONSerialization.data(withJSONObject: extras, options: []),
           let eventParamsString = String(data: eventParamsData, encoding: .utf8) {
            params["event_params"] = eventParamsString
        }
        
        fetchDataWithGET(
            apiRoute: "https://d33ftqsb9ygkos.cloudfront.net",
            params: params
        )
    }
    catch {
       
    }
}


private func fetchDataWithGET(apiRoute: String, params: [String: String]? = nil, headers: [String: String]? = nil) {
    var components = URLComponents(string:apiRoute)
    
    if let params = params {
        components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    
    guard let url = components?.url else {
        return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    
    if let headers = headers {
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
    }
    
    let task = URLSession.shared.dataTask(with: request) { (_, _, _) in
        
    }
    task.resume()
}

enum EventConstants: String {
    case INIT_CONNECT = "native_init_connect"
    case START_CONNECT = "native_start_connect"
    
    case SNA_CALLBACK_RESULT = "native_connectsdk__sna_callback_result"
    
    case ERROR_API_RESPONSE = "native_connectsdk__api_response_error"
    
    case STOP_CONNECT = "native_stop_connect"
    
    case SOCKET_CONNECTION_SUCCESS = "native_connectsdk_socket_connection_success"
    case SOCKET_CONNECTION_FAILURE = "native_connectsdk_socket_connection_failure"
    case SOCKET_DISCONNECTED = "native_connectsdk__socket_disconnected"
    case SOCKET_MESSAGE_RECEIVED = "native_connectsdk_socket_message"
    case SOCKET_ERROR = "native_connectsdk_socket_error"
}
