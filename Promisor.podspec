#
# Be sure to run `pod lib lint Promisor.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Promisor'
  s.version          = '1.0.0'
  s.summary          = 'A Swift implementation of Promise.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Promisor is an implementation of Promise in Swift. A promise represents the eventual result of an asynchronous operation.
Promises are very similar to the promises you make in real life. A promise can either be kept or broken.
                       DESC

  s.homepage         = 'https://github.com/enniobovyn/Promisor'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ennio Bovyn' => 'enniobovyn@gmail.com' }
  s.source           = { :git => 'https://github.com/enniobovyn/Promisor.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.swift_version = '4.0'

  s.source_files = 'Promisor/Classes/**/*'
  
  # s.resource_bundles = {
  #   'Promisor' => ['Promisor/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end
