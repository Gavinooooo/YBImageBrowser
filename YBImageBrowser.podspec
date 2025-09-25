

Pod::Spec.new do |s|


  s.name         = "YBImageBrowser"

  s.version      = "3.0.10"

  s.summary      = "iOS image browser with Performance optimization / iOS 图片浏览器 - 性能优化版"

  s.description  = <<-DESC
  					iOS 图片浏览器，功能强大，易于拓展，极致的性能优化和严格的内存控制让其运行更加的流畅和稳健。
  					新增 Performance 模块，包含智能预加载、内存自适应、渐进式加载等企业级性能优化功能。
                   DESC

  s.homepage     = "https://github.com/Gavinooooo/YBImageBrowser"

  s.license      = "MIT"

  s.author       = { "Gavin Liu" => "gavin@example.com" }

  s.platform     = :ios, "8.0"

  s.source       = { :git => "https://github.com/Gavinooooo/YBImageBrowser.git", :branch => "release/3.0.10" }

  s.requires_arc = true

  s.default_subspec = "Core"

  s.subspec "Core" do |core|
    core.source_files   = "YBImageBrowser/**/*.{h,m}"
    core.resources      = "YBImageBrowser/YBImageBrowser.bundle"
    core.dependency 'YYImage'
    core.dependency 'SDWebImage', '>= 5.0.0'
  end
  s.subspec "NOSD" do |core|
    core.source_files   = "YBImageBrowser/**/*.{h,m}"
    core.exclude_files  = "YBImageBrowser/WebImageMediator/YBIBDefaultWebImageMediator.{h,m}"
    core.resources      = "YBImageBrowser/YBImageBrowser.bundle"
    core.dependency 'YYImage'
  end

  s.subspec "Video" do |video|
    video.source_files = "Video/*.{h,m}"
    video.resources    = "Video/YBImageBrowserVideo.bundle"
    video.dependency 'YBImageBrowser/Core'
  end
  s.subspec "VideoNOSD" do |video|
    video.source_files = "Video/*.{h,m}"
    video.resources    = "Video/YBImageBrowserVideo.bundle"
    video.dependency 'YBImageBrowser/NOSD'
  end

end
