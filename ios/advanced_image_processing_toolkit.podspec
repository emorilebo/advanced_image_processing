#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint advanced_image_processing_toolkit.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'advanced_image_processing_toolkit'
  s.version          = '0.2.0'
  s.summary          = 'Advanced image processing toolkit for Flutter.'
  s.description      = <<-DESC
A comprehensive Flutter image processing toolkit: filters, geometric
transforms, watermarking, and ML-powered detection (objects, faces, text,
pose).
                       DESC
  s.homepage         = 'https://github.com/emorilebo/advanced_image_processing'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Godfrey Lebo' => 'emorylebo@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '12.0'
  s.swift_version    = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }

  # ML Kit native pods are pulled in by the `google_mlkit_*` Flutter plugins
  # themselves — no need to declare them here.
end
