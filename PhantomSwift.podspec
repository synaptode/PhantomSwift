Pod::Spec.new do |s|
  s.name             = 'PhantomSwift'
  s.version          = '1.0.0'
  s.summary          = 'A zero-dependency, modern iOS debugging toolkit.'
  s.description      = <<-DESC
PhantomSwift is a powerful, extensible iOS debugging library that provides real-time network interception, view inspection, performance monitoring, and more.
                       DESC

  s.homepage         = 'https://github.com/synaptode/PhantomSwift'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MRLF' => 'mrlf.synaptode@gmail.com' }
  s.source           = { :git => 'https://github.com/synaptode/PhantomSwift.git', :tag => s.version.to_s }

  s.ios.deployment_target = '12.0'
  s.swift_version = '5.0'

  s.source_files = 'Sources/PhantomSwift/**/*'
  s.frameworks = 'UIKit', 'Security'
end
