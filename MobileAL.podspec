#
#  Be sure to run `pod spec lint MobileAL.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|
  s.name         = "MobileAL"
  s.version      = "0.0.0"
  s.summary      = "Lightweight Audio library for iOS"

  s.description  = <<-DESC
                   DESC

  s.homepage     = "https://github.com/ykst/MobileCV"
  s.license      = { :type => 'MIT', :file => 'MIT-LICENSE.txt' }

  s.author       = { "Yohsuke Yukishita" => "ykstyhsk@gmail.com" }

  s.source       = { :git => "https://github.com/ykst/MobileAL.git", :tag => "0.0.0" }

  s.source_files  = 'src/**/*.{h,c,m}', 'src/**/*.glsl'
  s.exclude_files = 'Makefile'
  s.prefix_header_file = 'src/Utility.h'
  s.public_header_files = 'src/**/*.h'
  s.requires_arc = true

  s.frameworks = 'CoreAudio'

  #s.subspec 'Core' do |sub|
  #  sub.source_files  = 'src/Core/*.{h,m}', 'src/Core/shaders/*.glsl'
  #  sub.public_header_files = 'src/Core/*.h'
  #end
end
