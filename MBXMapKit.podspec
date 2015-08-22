Pod::Spec.new do |m|

  m.name    = 'MBXMapKit'
  m.version = '0.7.0'

  m.deprecated_in_favor_of = 'Mapbox-iOS-SDK'

  m.summary          = 'Lightweight Mapbox integration with MapKit on iOS.'
  m.description      = 'Lightweight Mapbox integration with MapKit on iOS for custom map styles and complete offline control.'
  m.homepage         = 'https://www.mapbox.com/mbxmapkit/'
  m.license          = 'BSD'
  m.author           = { 'Mapbox' => 'mobile@mapbox.com' }
  m.screenshot       = 'https://raw.githubusercontent.com/mapbox/mbxmapkit/packaging/screenshot.png'
  m.social_media_url = 'https://twitter.com/Mapbox'

  m.source = { :git => 'https://github.com/mapbox/mbxmapkit.git', :tag => m.version.to_s }

  m.ios.deployment_target = '7.0'

  m.source_files = 'MBXMapKit/*.{h,m}'

  m.requires_arc = true

  m.documentation_url = 'https://www.mapbox.com/mbxmapkit/'

  m.library = 'sqlite3'

end
