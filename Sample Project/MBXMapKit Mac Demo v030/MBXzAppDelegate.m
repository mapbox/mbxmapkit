//
//  MBXzAppDelegate.m
//  MBXMapKit Mac Demo v030
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXzAppDelegate.h"
#import <MapKit/MapKit.h>
#import "MBXRasterTileOverlay.h"


@interface MBXzAppDelegate ()

@property (weak) IBOutlet NSPopUpButton *popupButton;
@property (weak) IBOutlet MKMapView *mapView;
@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;
@property (weak) IBOutlet NSProgressIndicator *progressIndicator;

@property (nonatomic) NSInteger cacheHitCount;
@property (nonatomic) NSInteger httpSuccessCount;
@property (nonatomic) NSInteger httpFailureCount;
@property (nonatomic) NSInteger networkFailureCount;
@property (nonatomic) BOOL showStatisticsLog;

@end

@implementation MBXzAppDelegate

#pragma mark - Initialization

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Initialize the mapView here rather than in applicationDidFinishLaunching: in order to avoid
    // a delay which can let Apple's map show briefly while the Mapbox layer gets added
    //

    // Configure the cache
    //
    NSUInteger memoryCapacity = 4 * 1024 * 1024;
    NSUInteger diskCapacity = 40 * 1024 * 1024;
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:nil];
    //[URLCache removeAllCachedResponses];
    [NSURLCache setSharedURLCache:urlCache];

    // Configure cache and network statistics logging
    //
    [self addCacheAndNetworkNotifications];
    self.showStatisticsLog = YES;


    // Configure the mapView to use delegate callbacks for managing tile overlay layers, map centering, and adding
    // adding markers.
    //
    _mapView.rotateEnabled = NO;
    _mapView.pitchEnabled = NO;
    _mapView.delegate = self;

    [_progressIndicator startAnimation:self];
    _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
    _rasterOverlay.delegate = self;
    [_mapView addOverlay:_rasterOverlay];

    // Configure the popup button for selecting which map to show
    //
    NSArray *titles = [NSArray arrayWithObjects:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", nil];
    [_popupButton removeAllItems];
    [_popupButton addItemsWithTitles:titles];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self removeCacheAndNetworkNotifications];
}


#pragma mark - Notification stuff to collect cache and network statistics

- (void)addCacheAndNetworkNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSOperationQueue *queue = [NSOperationQueue mainQueue];

    // Add notification observers to collect statistics about resources loaded from the cache and over network connections
    //
    [center addObserverForName:MBXNotificationTypeCacheHit object:nil queue:queue usingBlock:^(NSNotification *note){
        self.cacheHitCount += 1;
    }];

    [center addObserverForName:MBXNotificationTypeHTTPSuccess object:nil queue:queue usingBlock:^(NSNotification *note){
        self.httpSuccessCount += 1;
    }];

    [center addObserverForName:MBXNotificationTypeHTTPFailure object:nil queue:queue usingBlock:^(NSNotification *note){
        self.httpFailureCount += 1;
    }];

    [center addObserverForName:MBXNotificationTypeNetworkFailure object:nil queue:queue usingBlock:^(NSNotification *note){
        self.networkFailureCount += 1;
    }];
}


- (void)removeCacheAndNetworkNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)logCacheAndNetworkStats
{
    // Show how many tile, TileJSON, simplestyle, or marker resources were loaded since the last log entry
    //
    if(self.showStatisticsLog)
    {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSLog(@"\n-- HTTP OK:%ld -- HTTP Fail:%ld -- Network Fail:%ld --",
                  (long)self.httpSuccessCount,
                  (long)self.httpFailureCount,
                  (long)self.networkFailureCount);

            self.cacheHitCount = 0;
            self.httpSuccessCount = 0;
            self.httpFailureCount = 0;
            self.networkFailureCount = 0;
        }];
    }
}


#pragma mark - Things for switching between maps

- (void)resetMapViewAndRasterOverlayDefaults
{
    // Start the progress spinner
    //
    [_progressIndicator startAnimation:self];

    // Reset the MKMapView to some reasonable defaults.
    //
    _mapView.mapType = MKMapTypeStandard;
    _mapView.scrollEnabled = YES;
    _mapView.zoomEnabled = YES;

    // Make sure that any downloads (tiles, metadata, marker icons) which might be in progress for
    // the old tile overlay are stopped, and remove the overlay and its markers from the MKMapView.
    // The invalidation step is necessary to avoid the possibility of visual glitching or crashes due to
    // delegate callbacks or asynchronous completion handlers getting invoked for downloads which might
    // be still in progress.
    //
    [_mapView removeAnnotations:_rasterOverlay.markers];
    [_mapView removeOverlay:_rasterOverlay];
    [_rasterOverlay invalidateAndCancel];
}



- (IBAction)popupButtonAction:(id)sender {
    if ([sender isKindOfClass:[NSPopUpButton class]])
    {
        NSPopUpButton *popup = (NSPopUpButton *)sender;
        switch([popup indexOfSelectedItem])
        {
            case 0:
                // OSM world map
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
                _rasterOverlay.delegate = self;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 1:
                // OSM over Apple satellite
                [self resetMapViewAndRasterOverlayDefaults];
                _mapView.mapType = MKMapTypeSatellite;
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-9tlo4knw" metadata:YES markers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 2:
                // Terrain under Apple labels
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-mf07hryq" metadata:YES markers:NO];
                _rasterOverlay.delegate = self;
                [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
                break;
            case 3:
                // Tilemill bounded region (scroll & zoom limited to programmatic control only)
                [self resetMapViewAndRasterOverlayDefaults];
                _mapView.scrollEnabled = NO;
                _mapView.zoomEnabled = NO;
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.NACIS2012" metadata:YES markers:NO];
                _rasterOverlay.delegate = self;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 4:
                // Tilemill region over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.clp-2011-11-03-1200" metadata:YES markers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 5:
                // Tilemill transparent over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.pdx_meters" metadata:YES markers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
        }
    }
}


#pragma mark - MKMapViewDelegate protocol implementation

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    [self logCacheAndNetworkStats];
}


- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    // This is boilerplate code to connect tile overlay layers with suitable renderers
    //
    if ([overlay isKindOfClass:[MBXRasterTileOverlay class]])
    {
        MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return renderer;
    }
    return nil;
}


- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    // This is boilerplate code to connect annotations with suitable views
    //
    if ([annotation isKindOfClass:[MBXPointAnnotation class]])
    {
        static NSString *MBXSimpleStyleReuseIdentifier = @"MBXSimpleStyleReuseIdentifier";
        MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:MBXSimpleStyleReuseIdentifier];
        if (!view)
        {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:MBXSimpleStyleReuseIdentifier];
        }
        view.image = ((MBXPointAnnotation *)annotation).image;
        view.canShowCallout = YES;
        return view;
    }
    return nil;
}


#pragma mark - MBXRasterTileOverlay delegate protocol implementation

- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error
{
    // This delegate callback is for centering the map once the map metadata has been loaded
    //
    if (!_mapView)
    {
        NSLog(@"Warning: the mapView property is not set (didLoadMetadata:)");
    }
    else if (error)
    {
        NSLog(@"Failed to load metadata for map ID %@ - (%@)", overlay.mapID, error?error:@"");
    }
    else
    {
        MKCoordinateRegion region = MKCoordinateRegionMake(overlay.center, MKCoordinateSpanMake(0, 360 / pow(2, overlay.centerZoom) * _mapView.frame.size.width / 256));

        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_mapView setRegion:region animated:NO];
        });
    }
}


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error
{
    // This delegate callback is for adding map markers to an MKMapView once all the markers for the tile overlay have loaded
    //
    if(!_mapView) {
        NSLog(@"Warning: the mapView property is not set (didLoadMarker:)");
    }
    else if (error)
    {
        NSLog(@"Failed to load markers for map ID %@ - (%@)", overlay.mapID, error?error:@"");
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_mapView addAnnotations:markers];
        });
    }
}

- (void)MBXRasterTileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:(MBXRasterTileOverlay *)overlay
{
    [_progressIndicator stopAnimation:self];
}


@end
