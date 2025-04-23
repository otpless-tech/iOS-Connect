// The Swift Programming Language
// https://docs.swift.org/swift-book


import UIKit
import SocketIO
import SafariServices
import os


public class OtplessSwiftConnect: NSObject, URLSessionDelegate {
    private var socketManager: SocketManager? = nil
    internal private(set) var socket: SocketIOClient? = nil
    internal private(set) var appId: String = ""
    private var roomRequestToken: String = ""
    internal private(set) var apiRepository: ApiRepository = ApiRepository()
    private lazy var roomTokenUseCase: RoomTokenUseCase = {
        return RoomTokenUseCase(apiRepository: apiRepository)
    }()
    private lazy var roomIdUseCase: RoomIDUseCase = {
        return RoomIDUseCase(apiRepository: apiRepository)
    }()
    private var roomRequestId: String = ""
    private var secret: String = ""
    
    internal private(set) var shouldLog = false
    
    private var eventCounter = 1
    
    public static let shared: OtplessSwiftConnect = {
        DeviceInfoUtils.shared.initialise()
        return OtplessSwiftConnect()
    }()
    
    public override init() {
        super.init()
    }
    
    public func enableSocketLogging() {
        self.shouldLog = true
    }
    
    public func initialize(
        appId: String,
        secret: String
    ) {
        self.appId = appId
        self.secret = secret
        
        sendEvent(event: .INIT_CONNECT)
        
        Task(priority: .medium, operation: { [weak self] in
            self?.roomRequestToken = await self?.roomTokenUseCase.invoke(appId: appId, secret: secret, isRetry: false) ?? ""
            self?.roomRequestId = await self?.roomIdUseCase.invoke(token: self?.roomRequestToken ?? "", isRetry: false) ?? ""
            
            guard let self = self else {
                sendEvent(event: .INIT_CONNECT, extras: ["error": "Could not create a socket connection because self was nil"])
                return
            }
            
            if !self.roomRequestId.isEmpty {
                self.openSocket()
            }
        })
    }
    
    func setupSocketEvents() {
        guard let socket = socket else {
            sendEvent(event: .SOCKET_CONNECTION_FAILURE, extras: ["error": "Could not create Socket.IO client"])
            Utils.otplessLog("OtplessConnect: Could not create socket connection")
            return
        }
        
        socket.on(clientEvent: .connect) { data, ack in
            sendEvent(event: .SOCKET_CONNECTION_SUCCESS)
            Utils.otplessLog("OtplessConnect: socket connected")
        }
        
        socket.on(clientEvent: .disconnect) { data, ack in
            sendEvent(event: .SOCKET_DISCONNECTED, extras: ["error": "Socket disconnected"])
            Utils.otplessLog("OtplessConnect: socket disconnected")
        }
        
        socket.on(clientEvent: .error) { data, ack in
            sendEvent(event: .SOCKET_ERROR, extras: ["error": data.description])
            Utils.otplessLog("OtplessConnect: Socket error: \(data)")
        }
        
        socket.on(clientEvent: .reconnectAttempt) { data, ack in
            sendEvent(event: .SOCKET_RECONNECT_ATTEMPT, extras: ["reconnectAttemptCount": data.description])
        }
        
        socket.on(clientEvent: .statusChange) { data, ack in
            sendEvent(event: .SOCKET_STATUS_CHANGE, extras: ["statusChangeData": data.description])
        }
        
        socket.on(clientEvent: .websocketUpgrade) { data, ack in
            sendEvent(event: .SOCKET_WEBSOCKET_UPGRADE)
        }
        
        socket.on("message") { [weak self] (data, ack) in
            if let parsedEvent = SocketEventParser.parseEvent(from: data) {
                sendEvent(event: .SOCKET_MESSAGE_RECEIVED, extras: ["messageId": parsedEvent.messageId])
                self?.handleParsedEvent(parsedEvent)
            } else {
                sendEvent(event: .SOCKET_MESSAGE_RECEIVED, extras: ["error": "Failed to parse socket message: \(Utils.jsonParamString(from: data) ?? "")"])
                Utils.otplessLog("OtplessConnect: Failed to parse event \(data)")
            }
        }
    }
    
    
    public func startOtpless() -> [String: Any] {
        var params: [String: Any] = [:]
        params["otpless_connect_id"] = roomRequestId
        params["v"] = 5
        params["otpl_instl_wa"] = DeviceInfoUtils.shared.hasWhatsApp
        params["otpl_sdk_type"] = "connect"
        params["otpl_platform"] = "iOS"
        sendEvent(event: .START_CONNECT, extras: ["start_params": Utils.convertDictionaryToString(params)])
        return params
    }
    
    public func cease() {
        socket?.disconnect()
        socketManager?.disconnect()
        socket = nil
        socketManager = nil
        roomRequestId = ""
        roomRequestToken = ""
        secret = ""
        appId = ""
        sendEvent(event: .STOP_CONNECT)
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

extension OtplessSwiftConnect {
    func openSocket() {
        let socketUrl = URL(string: "https://connect.otpless.app/?token=\(self.roomRequestId)")
        guard let socketUrl = socketUrl else {
            sendEvent(event: .SOCKET_CONNECTION_FAILURE, extras: ["error": "Socket URL could not be parsed."])
            Utils.otplessLog("Could not create socket url")
            return
        }
        self.socketManager = SocketManager(
            socketURL: socketUrl,
            config: [
                .log(shouldLog),
                .reconnects(true),
                .compress,
                .secure(true),
                .selfSigned(true),
                .sessionDelegate(self),
                .path("/socket.io"),
                .connectParams(["token": self.roomRequestId])
            ]
        )
        socketManager?.reconnect()
        guard let socketManager = self.socketManager else {
            sendEvent(event: .SOCKET_CONNECTION_FAILURE, extras: ["error": "SocketManager could not be created."])
            Utils.otplessLog("Could not create socket manager")
            return
        }
        self.socket = socketManager.defaultSocket
        
        guard let socket = self.socket else {
            sendEvent(event: .SOCKET_CONNECTION_FAILURE, extras: ["error": "Could not create socket."])
            Utils.otplessLog("Could not create socket")
            return
        }
        socket.connect()
        
        self.setupSocketEvents()
    }
    
    func getEventCounterAndIncrement() -> Int {
        let currentCounter = eventCounter
        eventCounter += 1
        return currentCounter
    }
}


@objc public protocol OtplessConnectDelegate: NSObjectProtocol {
    func onConnectResponse(_ response: [String: Any])
}
