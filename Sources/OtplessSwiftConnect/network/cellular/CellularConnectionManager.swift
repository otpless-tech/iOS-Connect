//
//  CellularConnectionManager.swift
//  OtplessSwiftConnect
//
//  Created by Sparsh on 20/03/25.
//


import Network
import os
#if canImport(UIKit)
import UIKit
#else
import Foundation
#endif

typealias ResultHandler = @Sendable (ConnectionResult) -> Void

/// Force connectivity to cellular only
@available(iOS 12.0, *)
final class CellularConnectionManager: @unchecked Sendable {
    
    private var connection: NWConnection?
    
    //Mitigation for tcp timeout not triggering any events.
    private var timer: Timer?
    private var CONNECTION_TIME_OUT = 7.0
    private var pathMonitor: NWPathMonitor?
    private let accessQueue = DispatchQueue(label: "com.otpless.cellular.connection.manager")
       private var _checkResponseHandler: ResultHandler?
    private var checkResponseHandler: ResultHandler? {
          get {
              accessQueue.sync { _checkResponseHandler }
          }
          set {
              accessQueue.async { self._checkResponseHandler = newValue }
          }
      }
    
    public convenience init(connectionTimeout: Double) {
        self.init()
        self.CONNECTION_TIME_OUT = connectionTimeout
    }
    
    func updateConnectionTimeout(_ connectionTimeout: Double) {
        self.CONNECTION_TIME_OUT = connectionTimeout
    }
    
    func open(url: URL, operators: String?, completion: @Sendable @escaping ([String : Any]) -> Void) {
        guard let _ = url.scheme, let _ = url.host else {
            completion(convertNetworkErrorToDictionary(err: NetworkError.other("No scheme or host found")))
            return
        }
        
        Utils.otplessLog("Connection timeout is \(CONNECTION_TIME_OUT)")
        
        // This closure will be called on main thread
        checkResponseHandler = { [weak self] (response) -> Void in
            guard let self = self else {
                var json = [String : Any]()
                json["error"] = "sdk_error"
                json["error_description"] = "Unable to carry on"
                completion(json)
                return
            }
            
            switch response {
            case .follow(let redirectResult):
                if let url = redirectResult.url {
                    self.createTimer()
                    if let checkResponseHandler = self.checkResponseHandler {
                        self.activateConnectionForDataFetch(url: url, completion: checkResponseHandler)
                    }
                } else {
                    self.cleanUp()
                }
            case .err(let error):
                self.cleanUp()
                completion(self.convertNetworkErrorToDictionary(err: error))
            case .dataOK(let connResp):
                self.cleanUp()
                completion(self.convertConnectionResponseToDictionary(resp: connResp))
            case .dataErr(let connResp):
                self.cleanUp()
                completion(self.convertConnectionResponseToDictionary(resp: connResp))
            }
        }

        //Initiating on the main thread to synch, as all connection update/state events will also be called on main thread
        DispatchQueue.main.async {
            self.startMonitoring()
            self.createTimer()
            if let checkResponseHandler = self.checkResponseHandler {
                self.activateConnectionForDataFetch(url: url, completion: checkResponseHandler)
            }
        }
    }
    
    func convertConnectionResponseToDictionary(resp: ConnectionResponse)  -> [String : Any] {
        let json = ["":""]
        do {
            // load JSON response into a dictionary
            if let body = resp.body, let dictionary = try JSONSerialization.jsonObject(with: body, options: .mutableContainers) as? [String : Any] {
                return dictionary
            }
        } catch {
                return convertNetworkErrorToDictionary(err: NetworkError.other("JSON deserializarion"))
        }
        return json
    }
    
    func convertNetworkErrorToDictionary(err: NetworkError) -> [String : Any] {
        var json = [String : Any]()
        switch err {
        case .invalidRedirectURL(let string):
            json["error"] = "sdk_redirect_error"
            json["error_description"] = string
        case .tooManyRedirects:
            json["error"] = "sdk_redirect_error"
            json["error_description"] = "Too many redirects"
        case .connectionFailed(let string):
            json["error"] = "sdk_connection_error"
            json["error_description"] = string
        case .connectionCantBeCreated(let string):
            json["error"] = "sdk_connection_error"
            json["error_description"] = string
        case .other(let string):
            json["error"] = "sdk_error"
            json["error_description"] = string
        }

        return json
    }
    
    func cancelExistingConnection() {
        if self.connection != nil {
            self.connection?.cancel() // This should trigger a state update
            self.connection = nil
        }
    }
    
    func createConnectionUpdateHandler(completion: @escaping @Sendable ResultHandler, readyStateHandler: @escaping @Sendable ()-> Void) -> @Sendable (NWConnection.State) -> Void {
        return { (newState) in
            switch (newState) {
            case .setup:
                break
            case .preparing:
                break
            case .ready:
                readyStateHandler() //Send and Receive
            case .waiting( _):
                break
            case .cancelled:
                break
            case .failed(let error):
                completion(.err(NetworkError.other("Connection State: Failed \(error.localizedDescription)")))
            @unknown default:
                completion(.err(NetworkError.other("Connection State: Unknown \(newState)")))
            }
        }
    }
    
    // As url.path property truncates the / if present in the last that is why string splitted
    func extractPathFromURL(urlString: String?) -> String? {
        guard let urlString = urlString,
              let hostRange = urlString.range(of: "//"),
              let pathStart = urlString[hostRange.upperBound...].range(of: "/") else {
            return nil
        }
        
        var path = urlString[pathStart.lowerBound...]
        
        if let queryStart = path.range(of: "?") {
            path = path[..<queryStart.lowerBound]
        }
        
        return String(path)
    }
    
    func createHttpCommand(url: URL) -> String? {
        guard let host = url.host, let scheme = url.scheme  else {
            return nil
        }
        var path = ""
        if #available(iOS 16.0, *) {
             path = url.path(percentEncoded: false)
        } else {
            // Fallback on earlier versions
            path = extractPathFromURL(urlString: url.absoluteString) ?? ""
        }
        // the path method is stripping ending / so adding it back
        if (url.absoluteString.hasSuffix("/") && !url.path.hasSuffix("/")) {
            path += "/"
        }

        if (path.count == 0) {
            path = "/"
        }

        var cmd = String(format: "GET %@", path)
        
        if let q = url.query {
            cmd += String(format:"?%@", q)
        }
        
        cmd += String(format:" HTTP/1.1\r\nHost: %@", host)
        if (scheme.starts(with:"https") && url.port != nil && url.port != 443) {
            cmd += String(format:":%d", url.port!)
        } else if (scheme.starts(with:"http") && url.port != nil && url.port != 80) {
            cmd += String(format:":%d", url.port!)
        }

        cmd += "\r\nAccept: text/html,application/json,application/xhtml+xml,application/xml,*/*"
        cmd += "\r\nConnection: close\r\n\r\n"
        return cmd
    }
    
    func createConnection(scheme: String, host: String, port: Int? = nil) -> NWConnection? {
        if scheme.isEmpty ||
            host.isEmpty ||
            !(scheme.hasPrefix("http") ||
              scheme.hasPrefix("https")) {
            return nil
        }
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5 //Secs
        tcpOptions.enableKeepalive = false
        
        var tlsOptions: NWProtocolTLS.Options?
        var fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.http)
        
        if (scheme.starts(with:"https")) {
            fport = (port != nil ? NWEndpoint.Port(integerLiteral: NWEndpoint.Port.IntegerLiteralType(port!)) : NWEndpoint.Port.https)
            tlsOptions = .init()
            tcpOptions.enableFastOpen = true //Save on tcp round trip by using first tls packet
        }
        
        let params = NWParameters(tls: tlsOptions , tcp: tcpOptions)
        params.serviceClass = .responsiveData

        params.requiredInterfaceType = .cellular
        params.prohibitExpensivePaths = false
        params.prohibitedInterfaceTypes = [.wifi, .loopback, .wiredEthernet]

        connection = NWConnection(host: NWEndpoint.Host(host), port: fport, using: params)
        
        return connection
    }
    
    func parseHttpStatusCode(response: String) -> Int {
        let status = response[response.index(response.startIndex, offsetBy: 9)..<response.index(response.startIndex, offsetBy: 12)]
        return Int(status) ?? 0
    }
    
    /// Decodes a response, first attempting with UTF8 and then fallback to ascii
    /// - Parameter data: Data which contains the response
    /// - Returns: decoded response as String
    func decodeResponse(data: Data) -> String? {
        guard let response = String(data: data, encoding: .utf8) else {
            return String(data: data, encoding: .ascii)
        }
        return response
    }
    
    func parseRedirect(requestUrl: URL, response: String) -> RedirectResult? {
        guard let _ = requestUrl.host else {
            return nil
        }
        //header could be named "Location" or "location"
        if let range = response.range(of: #"ocation: (.*)\r\n"#, options: .regularExpression) {
            let location = response[range]
            let redirect = location[location.index(location.startIndex, offsetBy: 9)..<location.index(location.endIndex, offsetBy: -1)]
            // some location header are not properly encoded
            let cleanRedirect = redirect.replacingOccurrences(of: " ", with: "+")
            if let redirectURL =  URL(string: String(cleanRedirect)) {
                return RedirectResult(url: redirectURL.host == nil ? URL(string: redirectURL.description, relativeTo: requestUrl)! : redirectURL, cookies: nil)
            } else {
                return nil
            }
        }
        return nil
    }
    
    func createTimer() {
        
        if let timer = self.timer, timer.isValid {
            Utils.otplessLog("Invalidating the existing timer")
            timer.invalidate()
        }
        
        Utils.otplessLog("Starting a new timer")
        self.timer = Timer.scheduledTimer(timeInterval: self.CONNECTION_TIME_OUT,
                                          target: self,
                                          selector: #selector(self.fireTimer),
                                          userInfo: nil,
                                          repeats: false)
    }
    
    @objc func fireTimer() {
        timer?.invalidate()
        checkResponseHandler?(.err(NetworkError.connectionCantBeCreated("Connection cancelled - time out")))
    }
    
    func startMonitoring() {
        
        if let monitor = pathMonitor { monitor.cancel() }
        
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { path in
            let interfaceTypes = path.availableInterfaces.map { $0.type }
            for interfaceType in interfaceTypes {
                switch interfaceType {
                case .wifi:
                    Utils.otplessLog("Path is Wi-Fi")
                case .cellular:
                    Utils.otplessLog("Path is Cellular ipv4 \(path.supportsIPv4.description) ipv6 \(path.supportsIPv6.description)")
                case .wiredEthernet:
                    Utils.otplessLog("Path is Wired Ethernet")
                case .loopback:
                    Utils.otplessLog("Path is Loopback")
                case .other:
                    Utils.otplessLog("Path is other")
                default:
                    Utils.otplessLog("Path is unknown")
                }
            }
        }
        
        pathMonitor?.start(queue: .main)
    }
    
    func stopMonitoring() {
        if let monitor = pathMonitor {
            monitor.cancel()
            pathMonitor = nil
        }
    }
    
    func cleanUp() {
        self.timer?.invalidate()
        self.stopMonitoring()
        self.cancelExistingConnection()
    }
    
    func activateConnectionForDataFetch(url: URL, completion: @escaping ResultHandler) {
        self.cancelExistingConnection()
        guard let scheme = url.scheme,
              let host = url.host else {
            completion(.err(NetworkError.other("URL has no Host or Scheme")))
            return
        }
        
        guard let command = createHttpCommand(url: url),
              let data = command.data(using: .utf8) else {
            completion(.err(NetworkError.other("Unable to create HTTP Request command")))
            return
        }
        
        connection = createConnection(scheme: scheme, host: host, port: url.port)
        if let connection = connection {
            connection.stateUpdateHandler = createConnectionUpdateHandler(completion: completion, readyStateHandler: { [weak self] in
                self?.sendAndReceiveWithBody(requestUrl: url, data: data, completion: completion)
            })
            // All connection events will be delivered on the main thread.
            connection.start(queue: .main)
        } else {
            Utils.otplessLog("Problem creating a connection")
            completion(.err(NetworkError.connectionCantBeCreated("Problem creating a connection \(url.absoluteString)")))
        }
    }
    
    func sendAndReceiveWithBody(requestUrl: URL, data: Data, completion: @escaping ResultHandler) {
        connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            if let err = error {
                Utils.otplessLog("Sending error: \(err.localizedDescription)")
                completion(.err(NetworkError.other(err.localizedDescription)))
                
            }
        }))
        
        timer?.invalidate()

        //Read the entire response body
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536){ data, context, isComplete, error in
            
            Utils.otplessLog("Receive isComplete: \(isComplete.description)")
            if let err = error {
                completion(.err(NetworkError.other(err.localizedDescription)))
                return
            }
            
            if let d = data, !d.isEmpty, let response = self.decodeResponse(data: d) {
                
                Utils.otplessLog("Response:\n \(response)")
                
                let status = self.parseHttpStatusCode(response: response)
                Utils.otplessLog("\n----\nHTTP status: \(status)")
                
                switch status {
                case 200...202:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataOK(ConnectionResponse(status: status, body: r)))
                    } else {
                        completion(.dataOK(ConnectionResponse(status: status, body: nil)))
                    }
                case 204:
                    completion(.dataOK(ConnectionResponse(status: status, body: nil)))
                case 301...303, 307...308:
                    guard let ru = self.parseRedirect(requestUrl: requestUrl, response: response) else {
                        completion(.err(NetworkError.invalidRedirectURL("Invalid URL - unable to parseRecirect")))
                        return
                    }
                    completion(.follow(ru))
                case 400...451:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(ConnectionResponse(status: status, body:r)))
                    } else {
                        completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                    }
                case 500...511:
                    if let r = self.getResponseBody(response: response) {
                        completion(.dataErr(ConnectionResponse(status: status, body:r)))
                    } else {
                        completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                    }
                default:
                    completion(.err(NetworkError.other("Unexpected HTTP Status \(status)")))
                }
            } else {
                completion(.err(NetworkError.other("Response has no data or corrupt")))
            }
        }
    }
    
    func getResponseBody(response: String) -> Data? {
        
        if let rangeContentType = response.range(of: #"Content-Type: (.*)\r\n"#, options: .regularExpression) {
            // retrieve content type
            let contentType = response[rangeContentType]
            let type = contentType[contentType.index(contentType.startIndex, offsetBy: 9)..<contentType.index(contentType.endIndex, offsetBy: -1)]
            if (type.contains("application/json") || type.contains("application/hal+json") || type.contains("application/problem+json")) {
                if let range = response.range(of: "\r\n\r\n") {
                    if let rangeTransferEncoding = response.range(of: #"Transfer-Encoding: chunked\r\n"#, options: .regularExpression) {
                        if (!rangeTransferEncoding.isEmpty) {
                            if let r1 = response.range(of: "\r\n\r\n") , let r2 = response.range(of:"\r\n0\r\n") {
                                let c = response[r1.upperBound..<r2.lowerBound]
                                if let start = c.firstIndex(of: "{") {
                                    let json = c[start..<c.index(c.endIndex, offsetBy: 0)]
                                    Utils.otplessLog("json: \(json)")
                                    let jsonString = String(json)
                                    guard let data = jsonString.data(using: .utf8) else {
                                        return nil
                                    }
                                    return data
                                }
                            }
                        }
                    }
                    let content = response[range.upperBound..<response.index(response.endIndex, offsetBy: 0)]
                    if let start = content.firstIndex(of: "{") {
                        let json = content[start..<response.index(response.endIndex, offsetBy: 0)]
                        Utils.otplessLog("json: \(json)")
                        let jsonString = String(json)
                        guard let data = jsonString.data(using: .utf8) else {
                            return nil
                        }
                        return data
                    }
                }
            }
        }
        return nil
    }
}

public struct RedirectResult {
    public var url: URL?
    public let cookies: [HTTPCookie]?
}

enum NetworkError: Error, Equatable {
    case invalidRedirectURL(String)
    case tooManyRedirects
    case connectionFailed(String)
    case connectionCantBeCreated(String)
    case other(String)
}

public struct ConnectionResponse {
    public var status: Int
    public let body: Data?
}

enum ConnectionResult {
    case err(NetworkError)
    case dataOK(ConnectionResponse)
    case dataErr(ConnectionResponse)
    case follow(RedirectResult)
}
