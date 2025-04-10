//
//  File.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 20/03/25.
//


extension OtplessSwiftConnect {
    func handleParsedEvent(_ socketEvent: SocketEventData) {
        switch socketEvent.eventType {
        case .appInfo:
            sendAppInfoToServer()
            break
        case .error:
            break
        case .responseOnCellularData:
            if let url = socketEvent.eventValue["url"] as? JSONValue,
               let urlStr = url.value as? String {
                startSNA(requestURLString: urlStr)
            }
            break
        case .unknown:
            break
        }
    }
}

extension OtplessSwiftConnect {
    func sendAppInfoToServer() {
        let appInfo = DeviceInfoUtils.shared.getAppInfo()
        sendSocketMessage(eventName: AppEventType.appInfo.rawValue, eventValue: appInfo)
    }
    
    func startSNA(requestURLString urlString: String) {
        self.apiRepository.performSNA(requestURL: urlString, completion: { [weak self] result in
            self?.sendSocketMessage(eventName: AppEventType.responseOnCellularData.rawValue, eventValue: result)
        })
    }
    
    func sendSocketMessage(_ messageName: String = "message", eventName: String, eventValue: [String: Any]) {
        guard let socket = socket else {
            return
        }
        
        socket.emit(
            messageName,
          [
            "event_name": eventName,
            "event_value": eventValue
            ]
        )
    }
}
