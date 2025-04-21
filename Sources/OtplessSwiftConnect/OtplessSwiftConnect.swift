// The Swift Programming Language
// https://docs.swift.org/swift-book


import UIKit
import SocketIO
import SafariServices
import os


public class OtplessSwiftConnect: NSObject, URLSessionDelegate {
    private var socketManager: SocketManager? = nil
    internal private(set) var socket: SocketIOClient? = nil
    private var appId: String = ""
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
    
    private var shouldLog = false
    
    public static let shared: OtplessSwiftConnect = {
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
        secret: String,
        onInitializationComplete: @escaping (_ success: Bool) -> Void
    ) {
        self.appId = appId
        self.secret = secret
        
        Task(priority: .medium, operation: { [weak self] in
            self?.roomRequestToken = await self?.roomTokenUseCase.invoke(appId: appId, secret: secret, isRetry: false) ?? ""
            self?.roomRequestId = await self?.roomIdUseCase.invoke(token: self?.roomRequestToken ?? "", isRetry: false) ?? ""
            
            guard let self = self else {
                DispatchQueue.main.async {
                    onInitializationComplete(false)
                }
                return
            }
            
            if !self.roomRequestId.isEmpty {
                self.openSocket()
            }
            
            DispatchQueue.main.async {
                onInitializationComplete(!self.roomRequestId.isEmpty && !self.roomRequestToken.isEmpty)
            }
        })
    }
    
    func setupSocketEvents() {
        guard let socket = socket else {
            os_log("OtplessConnect: Could not create socket connection")
            return
        }
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            if self?.shouldLog == true {
                os_log("OtplessConnect: socket connected")
            }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            if self?.shouldLog == true {
                os_log("OtplessConnect: socket disconnected")
            }
        }
        
        socket.on("message") { [weak self] (data, ack) in
            if let parsedEvent = SocketEventParser.parseEvent(from: data) {
                self?.handleParsedEvent(parsedEvent)
            } else {
                if self?.shouldLog == true {
                    print("OtplessConnect: Failed to parse event \(data)")
                }
            }
        }
    }
    
    
    public func getStartParams() -> [String: Any] {
        var params: [String: Any] = [:]
        params["otpless_connect_id"] = roomRequestId
        params["v"] = 5
        params["otpl_instl_wa"] = DeviceInfoUtils.shared.hasWhatsApp
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
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

extension OtplessSwiftConnect {
    func openSocket() {
        let socketUrl = URL(string: "https://connect.otpless.app/?token=\(self.roomRequestId)")
        guard let socketUrl = socketUrl else {
            os_log("Could not create socket url")
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
            os_log("Could not create socket manager")
            return
        }
        self.socket = socketManager.defaultSocket
        
        guard let socket = self.socket else {
            os_log("Could not create socket")
            return
        }
        socket.connect()
        
        self.setupSocketEvents()
    }
}


@objc public protocol OtplessConnectDelegate: NSObjectProtocol {
    func onConnectResponse(_ response: [String: Any])
}
