#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint advanced_image_processing_toolkit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'advanced_image_processing_toolkit'
  s.version          = '0.1.4'
  s.summary          = 'Advanced image processing toolkit for Flutter.'
  s.description      = <<-DESC
A comprehensive image processing toolkit for Flutter that includes basic filters, advanced effects, and ML-powered object recognition capabilities.
                       DESC
  s.homepage         = 'https://github.com/emorilebo/advanced_image_processing'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Godfrey Lebo' => 'emorylebo@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # ML Kit dependencies
  s.dependency 'GoogleMLKit/ObjectDetection', '~> 4.0.0'
  s.dependency 'GoogleMLKit/ImageLabeling', '~> 4.0.0'
  s.dependency 'GoogleMLKit/FaceDetection', '~> 4.0.0'
  s.dependency 'GoogleMLKit/TextRecognition', '~> 4.0.0'
  s.dependency 'GoogleMLKit/PoseDetection', '~> 4.0.0'
end
