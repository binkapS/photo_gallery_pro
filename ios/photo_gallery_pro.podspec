#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint photo_gallery_pro.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'photo_gallery_pro'
  s.version          = '1.1.0'
  s.summary          = 'Flutter plugin for accessing photos and videos from the device gallery (Android, iOS, Linux).'
  s.description      = <<-DESC
A Flutter plugin that exposes the device media gallery on Android, iOS, and
Linux through a typed Dart API: albums, media in albums, thumbnails, and
permissions. Read-only; original bytes are available via getOriginalBytes.
                       DESC
  s.homepage         = 'https://binkap.com/packages/photo_gallery_pro'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'binkapS' => 'https://github.com/binkapS' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # Ships the privacy manifest declaring photo-library access.
  # See https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'photo_gallery_pro_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
