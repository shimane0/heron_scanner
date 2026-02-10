#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint heron_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'heron_scanner'
  s.version          = '1.0.0'
  s.summary          = 'A barcode scanner plugin combining camera and Google ML Kit.'
  s.description      = <<-DESC
A Flutter plugin that integrates camera and google_mlkit_barcode_scanning for
high-performance barcode scanning with scan window filtering on the native side.
                       DESC
  s.homepage         = 'https://github.com/shimane0/heron_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.5'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
