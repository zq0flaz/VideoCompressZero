#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'video_compress_zero'
  s.version          = '3.1.4'
  s.swift_version    = '5.0'
  s.summary          = 'A fork of video_compress with iOS/Android fixes and improvements.'
  s.description      = <<-DESC
A fork of the original 'video_compress' package version 3.1.4, updated to support Android API 35 and Gradle 8, 
with improved Android compatibility and fixes. Includes progress tracking fixes for iOS.
                       DESC
  s.homepage         = 'https://github.com/zq0flaz/VideoCompressZero'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zq' => '' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.ios.deployment_target = '12.0'
end

