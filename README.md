MBXMapKit
---------

MBXMapKit extends Apple's MapKit API to integrate with maps hosted on mapbox.com, combining the performance of native maps with convenience and integration similar to Mapbox.js. With MBXMapKit, your app is responsible for providing and managing its own MKMapView instance, while MBXMapKit provides tile overlays, annotations, and an offline map downloader so you can easily display maps from mapbox.com, both online and offline.

[![](https://raw.github.com/mapbox/mbxmapkit/packaging/screenshot.png)]()

### Features

The main features which MBXMapKit adds to MapKit are:
 * **Mapbox Markers:** If you've configured markers for your map using the mapbox.com editor, MBXMapKit makes it easy to add them to your MKMapView as MKShape annotations. You'll need to include some simple boilerplate code in your view controller's `mapView:viewForAnnotation:` to connect annotations with regular MKAnnotationView instances (see iOS sample app).
 * **Performance Caching:** MBXMapKit uses NSURLSession and NSURLCache for performance caching of the tiles, json, and icons required for loading maps. In contrast to the Mapbox iOS SDK and earlier versions of MBXMapKit, this is a traditional cache which is not designed to be used for long term persistence of map data while offline. That capability is provided by a separate mechanism.
 * **Offline Maps:** MBXMapKit now includes an offline map downloader to manage the download of all resources (tiles, json, and icons) necessary to display requested map regions while offline. The offline map downloader provides download progress updates, an internal mechanism for persistant storage of multiple offline map regions, the ability to remove specific offline map regions from disk, and the ability to include offline map data in iCloud backups (the default is to *exclude* offline map data from backups).
 * **Online Maps:** You can initialize a raster tile layer using a map ID, and MBXMapKit will handle the details of generating tile URLs and asynchronously loading metadata and markers. With MBXMapKit's delegate callbacks for asynchronously loaded resources, you have the option to immediately start rendering your map, then as the necessary data becomes available, to adjust the visible region and add markers to match how the map is configured in the mapbox.com editor.


### Conceptual Overview

The fundamental concept to understand about MBXMapKit is that, as of version 0.3.0, it is designed to add features to Apple's MKMapKit rather than to replace or encapsulate MKMapKit. The previous approach with versions 0.1.0 through 0.2.1 was to encapsulate MKMapKit by managing an instance of MKMapView, but that turned out to be impractical for apps which need more than a minimal level of control over the map's configuration.

Starting with MBXMapKit 0.3.0, you are now responsible for managing your own MKMapView, and MBXMapKit will stay out of your way. MBXMapKit provides MKTileOverlay and MKShape subclass instances which you can add to your MKMapView in combination with overlays and annotations from other sources. To see how MBXMapKit makes that process fairly painless, and for several examples of configuring MKMapView for different visual goals, please take a look at the view controller in the iOS sample app.

Another key idea introduced with MBXMapKit 0.3.0 is that making a clear distinction between performance caching and persistent storage facilitates a straightforward and dependable implementation for offline maps. Both online and offline map data is requested through NSURLCache for performance, but the offline map data is subsequently stored separately on disk for persistence. So, if iOS decides it needs to free up disk space by deleting items in app cache directories, your offline map data won't be affected.

The way that MBXMapKit is designed to be used revolves around the idea of instantiating MBXRasterTileOverlay instances (a subclass of MKTileOverlay) and adding them to, or removing them from, your MKMapView. Raster tile overlay objects are intended to be treated as immutable once they've been initialized, although the fact that some map resources necessarily must be loaded asynchronously complicates the concept a bit. The design intention is that if you want to switch the map ID which is being shown in your MKMapView, the way to do it is remove the visible raster tile overlay which you initialized with the old map ID, then add a new raster tile overlay which you've initialized with a new map ID. If you're expecting to set a map ID property, that won't work any more, but that's a good thing. The new approach introduced in MBXMapKit 0.3.0 cooperates with the design of MKMapKit in a more natural manner than the old approach.


### Installation

Note: This changed significantly as of version 0.3.0!

To include MBXMapKit in your app you will need to:
 1. Copy all the .m and .h files from the mbxmapkit folder into your project.
 2. Make sure that the .m files are included in your build target (select project, select build target, select Build Phases tab, expand the Compile Sources heading, and make sure all the .m files are listed).
 3. Make sure you have the map capability turned on for your build target (select project, select build target, select Capabilities tab, flip the switch to "ON" for Maps).
 4. Make sure that your build target is linked with 'libsqlite3.dylib' and 'MapKit.framework' (select project, select build target, select Build Phases tab, expand Link Binary With Libraries, and check the list). When you turn on the map capability, the MapKit framework should be added automatically, but you will probably need to add libsqlite3.dylib unless you are already using sqlite for something.
 5. Study the view controller in the iOS sample app. It's meant to be liberally copied and pasted. In particular, take a look at `viewDidLoad`, `resetMapViewAndRasterOverlayDefaults`, `actionSheet:clickedButtonAtIndex:`, the MBXOfflineMapDownloaderDelegate callbacks, `mapView:rendererForOverlay:`, `mapView:viewForAnnotation:`, and the MBXRasterTileOverlayDelegate callbacks.
 6. Provide some *prominent* means to display any applicable map data copyright attribution messages. For maps which include OSM data, that means you need something which links to the OSM copyright page. See https://www.mapbox.com/help/attribution/ and http://www.openstreetmap.org/copyright for details.


### Supported Platforms

As of version 0.3.0, MBXMapKit is officially supported only for iOS 7.0 and later. While iOS is the main priority, we also hope to keep things OS X friendly (10.9 and later). That means you may notice instances of `#if TARGET_OS_IPHONE` around UIImage/NSImage and such, and it's possible the OS X side of some of those things may be broken. During the development from 0.2.1 to 0.3.0, we were maintaining an OS X sample app to match the iOS sample app, but it ended up consuming a lot of time and slowing down progress on iOS, so we pulled back for now.

If you encounter an OS X related problem and want to file an issue or pull request on GitHub, that would be welcome and appreciated. In particular, if you're working on an OS X app which needs something more than Mapbox.js in a WebView (offline maps?) we'd like to hear about it.


### Requirements

 * iOS 7.0+
 * Xcode 5+
 * Automatic Reference Counting (ARC)


### Related

Check out the [overview guide](http://mapbox.com/mbxmapkit/) for more details. 

You might also be interested in the [Mapbox iOS SDK](http://mapbox.com/mapbox-ios-sdk/), which is a ground-up rewrite meant as a replacement for Apple's MapKit, not an extension of it. If you've always wished MapKit was open source for complete customizability, the Mapbox iOS SDK is for you. 
