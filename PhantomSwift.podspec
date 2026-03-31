Pod::Spec.new do |s|
  s.name             = 'PhantomSwift'
  s.version          = '1.0.3'
  s.summary          = 'Zero-dependency iOS debugging toolkit with 25 modules: network inspector, memory leak tracker, UI hierarchy, and more.'
  s.description      = <<-DESC
PhantomSwift is an open-source, zero-dependency iOS debugging library for Swift developers.
It provides 25 rich diagnostic modules including network inspection, memory leak detection,
3D view hierarchy exploration, performance monitoring, request interception, bad network simulation,
feature flags, security audit, and more — all in a single package.
Compatible with UIKit and SwiftUI. All code is wrapped in #if DEBUG for production safety.
An alternative to FLEX, Netfox, and Pulse with no external dependencies required.
                       DESC

  s.homepage         = 'https://github.com/synaptode/PhantomSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MRLF' => 'mrlf.synaptode@gmail.com' }
  s.source           = { :git => 'https://github.com/synaptode/PhantomSwift.git', :tag => "v#{s.version}" }

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.9'

  s.source_files = 'Sources/PhantomSwift/**/*'
  s.frameworks = 'UIKit', 'Security'
end
