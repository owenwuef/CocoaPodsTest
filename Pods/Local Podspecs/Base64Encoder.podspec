Pod::Spec.new do |s|
  s.name         = "Base64Encoder"
  s.version      = "0.0.1"
  s.summary      = "Do Base64 Encode and Decode for string."
  s.homepage     = "https://github.com/chenyongwei/Base64Encoder-iOS"
  s.author       = { "Yongwei Chen" => "iamywchen@gmail.com" }
  s.source       = { :git => "https://github.com/chenyongwei/Base64Encoder-iOS" }
  s.platform     = :ios, '5.0'
  s.source_files = 'Source', 'Base64Encoder-iOS/*.{h,m}'
  s.requires_arc = true
end