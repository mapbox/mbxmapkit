MBXMapKit
---------

MBXMapKit extends Apple's MapKit to integrate with maps hosted on [Mapbox](http://mapbox.com), combining the performance of native maps with the convenience and integration similar to [Mapbox.js](http://mapbox.com/mapbox.js). With MBXMapKit, your app is responsible for providing and managing its own `MKMapView` instance, while MBXMapKit provides tile overlays, annotations, and an offline map downloader so you can easily display maps from Mapbox both online and offline.

[![](https://raw.github.com/mapbox/mbxmapkit/packaging/screenshot.png)]()

### Features

The main features which MBXMapKit adds to MapKit are:

 * **Mapbox Markers:** If you've configured markers for your map using the [Mapbox online editor](https://www.mapbox.com/editor), MBXMapKit makes it easy to add them to your `MKMapView` as `MKShape` annotations. You'll need to include some simple boilerplate code in your view controller's `-mapView:viewForAnnotation:` to connect annotations with regular `MKAnnotationView` instances (see the iOS sample app).

 * **Performance Caching:** MBXMapKit uses `NSURLSession` and `NSURLCache` for performance caching of the tiles, JSON metadata, and icons required for loading maps. In contrast to the [Mapbox iOS SDK](http://mapbox.com/mapbox-ios-sdk) and earlier versions of MBXMapKit, this is a traditional cache which is not designed to be used for long term persistence of map data while offline. That capability is provided by a separate mechanism.
 
 * **Offline Maps:** MBXMapKit now includes an offline map downloader to manage the download of all resources (tiles, JSON metadata, and icons) necessary to display requested map regions while offline. The offline map downloader provides download progress updates, an internal mechanism for persistant storage of multiple offline map regions, the ability to remove specific offline map regions from disk, and the ability to include offline map data in iCloud backups (the default however is to *exclude* offline map data from backups).

 * **Online Maps:** You can initialize a raster tile layer using a [Mapbox map ID](https://www.mapbox.com/help/define-map-id/), and MBXMapKit will handle the details of generating tile URLs and asynchronously loading metadata and markers. With MBXMapKit's delegate callbacks for asynchronously loaded resources, you have the option to immediately start rendering your map, then as the necessary data becomes available, to adjust the visible region and add markers to match how the map is configured in the Mapbox online editor.

### Conceptual Overview

The fundamental concept to understand about MBXMapKit is that, as of version `0.3.0`, it is designed to add features to Apple's MapKit rather than to replace or encapsulate MapKit. The previous approach with versions `0.1.0` through `0.2.1` was to encapsulate MapKit by managing an instance of `MKMapView`, but that turned out to be impractical for apps which need more than a minimal level of control over the map's configuration.

Starting with MBXMapKit `0.3.0`, you are now responsible for managing your own `MKMapView`, and MBXMapKit will stay out of your way. MBXMapKit provides `MKTileOverlay` and `MKShape` subclass instances which you can add to your `MKMapView` in combination with overlays and annotations from other sources. To see how MBXMapKit makes that process fairly painless, and for several examples of configuring `MKMapView` for different visual goals, please take a look at the [view controller in the iOS sample app](./Sample Project/MBXMapKit iOS/MBXViewController.m).

Another key idea introduced with MBXMapKit `0.3.0` is that making a clear distinction between performance caching and persistent storage facilitates a straightforward and dependable implementation for offline maps. Both online and offline map data is requested through `NSURLCache` for performance, but the offline map data is subsequently stored separately on disk for persistence. So, if iOS decides it needs to free up disk space by deleting items in app cache directories, your offline map data won't be affected.

The way that MBXMapKit is designed to be used revolves around the idea of instantiating `MBXRasterTileOverlay` instances (a subclass of `MKTileOverlay`) and adding them to, or removing them from, your `MKMapView`. Raster tile overlay objects are intended to be treated as immutable once they've been initialized, although the fact that some map resources necessarily must be loaded asynchronously complicates the concept a bit. The design intention is that if you want to switch the map ID which is being shown in your `MKMapView`, the way to do it is remove the visible raster tile overlay which you initialized with the old map ID, then add a new raster tile overlay which you've initialized with a new map ID. If you're expecting to set a map ID property, that won't work any more, but that's a good thing. The new approach introduced in MBXMapKit `0.3.0` cooperates with the design of `MKMapKit` in a more natural manner than the old approach.


### Linking Requirements

MBXMapKit requires `libsqlite3.dylib` and `MapKit.framework` to be linked with your build target in order to compile properly.



### Getting Help

If you have questions about how to use MBXMapKit, or are encountering problems, here are our suggestions for how to proceed:

 1. Read all of this README, review the documentation in the MBXMapKit header files, and check if what you're trying to do is similar to anything in the sample app.
 
 2. Google your problem or error message. This can be very helpful for distinguishing MBXMapKit specific problems from more general issues with MKMapKit, and it may also guide you to relevant GitHub issues or StackOverflow questions. In many cases, documentation and blog posts about using MKMapKit will also be applicable to MBXMapKit.
 
 3. Familiarize yourself with the documentation and developer resources on Mapbox.com ([Help](https://www.mapbox.com/help/), [Foundations](https://www.mapbox.com/foundations/), [Developers](https://www.mapbox.com/developers/)).
 
 4. Take a look at the MBXMapKit [issues](https://github.com/mapbox/mbxmapkit/issues?state=open) on GitHub.
 
 5. Take a look at [Mapbox questions](http://stackoverflow.com/questions/tagged/mapbox?sort=votes&pageSize=100) on StackOverflow

 6. If none of that helps, you can file an [issue](https://github.com/mapbox/mbxmapkit/issues?state=open) on GitHub, ask a question on [StackOverflow](http://stackoverflow.com/questions/tagged/mapbox?sort=votes&pageSize=100), or [contact](https://www.mapbox.com/contact/) Mapbox support. Specifically for MBXMapKit (vs the iOS SDK), GitHub is best for possible bug reports, feature requests, and things generally having to do with improving MBXMapKit. You can also ask usage questions on StackOverflow (please tag as Mapbox and MBXMapKit). Contacting support is good for asking questions involving proprietary information or getting priority support for premium and enterprise accounts (please be sure to let us know who you are if you're using an email address which isn't associated with your Mapbox account).



### Getting the Latest Release from GitHub

Generally speaking, MBXMapKit follows the conventions described by GitHub's [Release Your Software](https://github.com/blog/1547-release-your-software) post.

Typically we develop new features as branches, and then merge them into the *master* as we are preparing for a release. When an official release is ready, we create a tag with the version number. You can view the list of releases at https://github.com/mapbox/mbxmapkit/releases

### Installation

Note: This changed significantly as of version `0.3.0`!

To include MBXMapKit in your app you will need to:

 1. Copy all the `.m` and `.h` files from the mbxmapkit folder into your project.
 
 1. Make sure that the `.m` files are included in your build target (select the project, select build target, select *Build Phases* tab, expand the *Compile Sources* heading, and make sure all the `.m` files are listed).
 
 1. Make sure you have the map capability turned on for your build target (select project, select build target, select *Capabilities* tab, flip the switch to `ON` for Maps).
 
 1. Make sure that your build target is linked with `libsqlite3.dylib` and `MapKit.framework` (select project, select build target, select *Build Phases* tab, expand *Link Binary With Libraries*, and check the list). When you turn on the map capability, the MapKit framework should be added automatically, but you will probably need to add `libsqlite3.dylib` unless you are already using SQLite for something.
 
 1. Study the view controller in the iOS sample app. It's meant to be liberally copied and pasted. In particular, take a look at `-viewDidLoad`, `-resetMapViewAndRasterOverlayDefaults`, `-actionSheet:clickedButtonAtIndex:`, the `MBXOfflineMapDownloaderDelegate` callbacks, `-mapView:rendererForOverlay:`, `-mapView:viewForAnnotation:`, and the `MBXRasterTileOverlayDelegate` callbacks.
 
 1. **Provide some prominent means to display any applicable map data copyright attribution messages.** For maps which include [OpenStreetMap](http://mapbox.com/about/maps) data, that means you need something which links to the OSM copyright page (see sample app for an example). More details are available at https://www.mapbox.com/help/attribution/ and http://www.openstreetmap.org/copyright. 

### Understanding the Sample App

The sample app is meant to demonstrate the full capabilities of MBXMapKit and to show examples of different ways to configure an `MKMapView`. We've also found it to be useful for testing for responsiveness and visual glitching during work on the API implementation.

A quick tour:

 1. Start the sample app

 1. Tap the info button in the bottom right corner to bring up an action sheet with several map configurations and an option to view the attribution dialog. 
 
 1. Try the different map configurations, then take a look at `-resetMapViewAndRasterOverlayDefaults` and `-actionSheet:clickedButtonAtIndex:` from `MBXViewController.m` to understand what's going on. The basic idea is that when the map configuration gets switched, the `MKMapView` is reverted to a known state by removing overlays and markers, then new overlays and markers are added for the new configuration.
 
 1. Note that *World baselayer, no Apple* map includes several orange swim markers in Santa Cruz, CA. The callout text comes from the map's `markers.geojson` file, which is loaded from the Mapbox API, and the icons are also loaded from the Mapbox API after the necessary specifications are parsed out of `markers.geojson`. The map center coordinate and zoom scale come from the map's metadata JSON (i.e., `your-map-id.json`). The markers, centering, and zoom get applied to the map by way of the view controller's `MBXRasterTileOverlayDelegate` callback implementations.
 
 1. Note how *Offline map downloader* provides a view in the center of the screen with controls to begin, cancel, suspend, and resume the downloading of an offline map region. To select the region to be downloaded, just adjust the visible map region before hitting the begin button. When a download is active, you should see the progress indicator at the bottom of the screen. The progress indicator will remain on screen if you switch to other maps. If you kill the app before the download is complete, it should resume when you re-launch the app.
 
 1. Note how the *Offline map viewer* will show the most recent offline map region which was completely downloaded at the time you switched to *Offline map viewer*. Note how the offline map includes markers, initial centering, and initial zoom, even when airplane mode is enabled. There is also a button with a confirmation dialog for deleting all the stored maps. While the sample app only shows the most recently downloaded offline map, the API is designed so that you can enumerate all the available offline maps and use whichever ones you want.

### Supported Platforms

As of version `0.3.0`, MBXMapKit is officially supported only for iOS 7.0 and later. While iOS is the main priority, we also hope to keep things OS X friendly (10.9 and later since MapKit is required). That means you may notice instances of `#if TARGET_OS_IPHONE` around `UIImage`/`NSImage` and such, and it's possible the OS X side of some of those things may be broken. During the development from `0.2.1` to `0.3.0`, we were maintaining an OS X sample app to match the iOS sample app, but it ended up consuming a lot of time and slowing down progress on iOS, so we pulled back for now.

If you encounter an OS X related problem and want to file an issue or pull request on GitHub, that would be welcome and appreciated. In particular, if you're working on an OS X app which needs something more than Mapbox.js in a `WebView` (offline maps?) we'd [like to hear about it](http://github.com/mapbox/mbxmapkit/issues/new).

### Requirements

 * iOS 7.0+
 * Xcode 5+
 * Automatic Reference Counting (ARC)

### See Also

Check out the [overview guide](http://mapbox.com/mbxmapkit/) for more details. 

You might also be interested in the [Mapbox iOS SDK](http://mapbox.com/mapbox-ios-sdk/), which is a ground-up rewrite meant as a replacement for Apple's MapKit, not an extension of it. If you've always wished MapKit was open source for complete customizability, the Mapbox iOS SDK is for you. 
