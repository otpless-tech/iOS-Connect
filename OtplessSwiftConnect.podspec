Pod::Spec.new do |s|
    s.name             = 'OtplessSwiftConnect'
    s.version          = '1.0.0'
    s.summary          = 'A Swift SDK for integrating Otpless Pre Build UI.'
  
    s.description      = <<-DESC
                          OtplessSwiftConnect is a Swift-based SDK that enables seamless 
                          integration with the Otpless platform for user authentication, using Otpless' socket connection.
                         DESC
  
    s.homepage         = 'https://github.com/otpless-tech/iOS-Connect.git'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Sparsh' => 'sparsh.chadha@otpless.com' }
    s.source           = { :git => 'https://github.com/otpless-tech/iOS-Connect.git', :tag => s.version.to_s }
  
    s.platform         = :ios, '13.0'
    s.swift_version    = '5.9'
  
    s.source_files     = 'Sources/OtplessSwiftConnect/**/*.{swift}'

    s.resource_bundles = {
        'OtplessSwiftConnect' => ['Sources/PrivacyInfo.xcprivacy']
    }
  
    s.dependency 'Socket.IO-Client-Swift', '~> 16.1.1'
  end
  
