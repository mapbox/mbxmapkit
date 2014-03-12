//
//  MBXzAppDelegate.m
//  MBXMapKit Mac Demo v030
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXzAppDelegate.h"
#import <MapKit/MapKit.h>
#import "MBXSimplestyle.h"
#import "MBXRasterTileOverlay.h"
#import "MBXCacheManager.h"


@interface MBXzAppDelegate ()

@property (weak) IBOutlet NSPopUpButton *popupButton;
@property (weak) IBOutlet MKMapView *mapView;
@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;
@property (nonatomic) MBXSimplestyle *simplestyle;

@property (nonatomic) NSInteger cacheHitCount;
@property (nonatomic) NSInteger httpSuccessCount;
@property (nonatomic) NSInteger httpFailureCount;
@property (nonatomic) NSInteger networkFailureCount;

@end

@implementation MBXzAppDelegate

#pragma mark - Initialization

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Initialize the mapView here rather than in applicationDidFinishLaunching: in order to avoid
    // a delay which can let Apple's map show briefly while the Mapbox layer gets added
    //

    [self addCacheAndNetworkNotifications];

    //[[MBXCacheManager sharedCacheManager] clearEntireCache];

    // Configure the mapView to use delegate callbacks for managing tile overlay layers, map centering, and adding
    // adding markers.
    //
    _mapView.delegate = self;

    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.delegate = self;
    _rasterOverlay.mapID = @"examples.map-pgygbwdm";

    _simplestyle = [[MBXSimplestyle alloc] init];
    _simplestyle.delegate = self;
    _simplestyle.mapID = @"examples.map-pgygbwdm";

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
    [center addObserverForName:MBXNotificationCacheHit object:nil queue:queue usingBlock:^(NSNotification *note){
        self.cacheHitCount += 1;
    }];

    [center addObserverForName:MBXNotificationHTTPSuccess object:nil queue:queue usingBlock:^(NSNotification *note){
        self.httpSuccessCount += 1;
    }];

    [center addObserverForName:MBXNotificationHTTPFailure object:nil queue:queue usingBlock:^(NSNotification *note){
        self.httpFailureCount += 1;
    }];

    [center addObserverForName:MBXNotificationNetworkFailure object:nil queue:queue usingBlock:^(NSNotification *note){
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
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSLog(@"\n-- Cache:%ld -- HTTP OK:%ld -- HTTP Fail:%ld -- Network Fail:%ld --",
              (long)self.cacheHitCount,
              (long)self.httpSuccessCount,
              (long)self.httpFailureCount,
              (long)self.networkFailureCount);

        self.cacheHitCount = 0;
        self.httpSuccessCount = 0;
        self.httpFailureCount = 0;
        self.networkFailureCount = 0;
    }];
}


#pragma mark - Things for switching between maps

- (void)resetMapViewAndRasterOverlayDefaults
{
    // This method prepares the MKMapView to switch overlays. Note that the specific order
    // in which things happen is quite important. One of the goals here is to fully disconnect old
    // tile overlays, annotations, and simplestyle prior to adding their new replacements. The
    // consequences of not doing that could potentially include stuff like EXEC_BAD_ACCESS, so it's
    // good to handle these things carefully.
    //
    _mapView.mapType = MKMapTypeStandard;

    // Set up a new tile overlay to account for the possibility that there are still tiles or TileJSON being downloaded
    //
    _rasterOverlay.delegate = nil;
    [_mapView removeOverlays:_mapView.overlays];
    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.delegate = self;

    // Set up a new simplestyle object to account for the possibility that there are still point icons being downloaded
    //
    _simplestyle.delegate = nil;
    [_mapView removeAnnotations:_mapView.annotations];
    _simplestyle = [[MBXSimplestyle alloc] init];
    _simplestyle.delegate = self;

    _mapView.scrollEnabled = YES;
    _mapView.zoomEnabled = YES;
    _rasterOverlay.canReplaceMapContent = YES;
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
                _rasterOverlay.mapID = _simplestyle.mapID = @"examples.map-pgygbwdm";
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 1:
                // OSM over Apple satellite
                [self resetMapViewAndRasterOverlayDefaults];
                _mapView.mapType = MKMapTypeSatellite;
                _rasterOverlay.canReplaceMapContent = NO;
                _rasterOverlay.mapID = @"justin.map-9tlo4knw";
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 2:
                // Terrain under Apple labels
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay.mapID = @"justin.map-mf07hryq";
                [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
                break;
            case 3:
                // Tilemill bounded region (scroll & zoom limited to programmatic control only)
                [self resetMapViewAndRasterOverlayDefaults];
                _mapView.scrollEnabled = NO;
                _mapView.zoomEnabled = NO;
                _rasterOverlay.mapID = @"justin.NACIS2012";
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 4:
                // Tilemill region over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay.canReplaceMapContent = NO;
                _rasterOverlay.mapID = @"justin.clp-2011-11-03-1200";
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 5:
                // Tilemill transparent over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay.canReplaceMapContent = NO;
                _rasterOverlay.mapID = @"justin.pdx_meters";
                [_mapView addOverlay:_rasterOverlay];
                break;
        }
    }
}


#pragma mark - Delegate protocol implementations (customize as needed)

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


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMapID:(NSString *)mapID
{
    // This is for centering the map once the TileJSON has been loaded
    //
    if(_mapView) {
        MKCoordinateRegion region = MKCoordinateRegionMake(overlay.center, MKCoordinateSpanMake(0, 360 / pow(2, overlay.centerZoom) * _mapView.frame.size.width / 256));
        [_mapView setRegion:region animated:NO];
    }
    else
    {
        NSLog(@"Warning: the mapView property is not set (didLoadTileJSONForTileOverlay:)");
    }
}


- (void)MBXSimplestyle:(MBXSimplestyle *)simplestyle didParsePoint:(MBXPointAnnotation *)pointAnnotation
{
    // This is for adding points to an MKMapView when they are successfully parsed from the simplestyle
    //
    if(_mapView) {
        [_mapView addAnnotation:pointAnnotation];
    }
    else
    {
        NSLog(@"Warning: the mapView property is not set (didParseSimplestylePoint:)");
    }
}


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailToLoadMapID:(NSString *)mapID withError:(NSError *)error
{
    // This is for handling situations when something goes wrong with the TileJSON
    //
    NSLog(@"Failed to load TileJSON for map ID %@ - (%@)",mapID, error?error:@"");
}


- (void)MBXSimplestyle:(MBXSimplestyle *)simplestyle didFailToLoadMapID:(NSString *)mapID withError:(NSError *)error
{
    // This is for handling situations when something goes wrong with the simplestyle
    //
    NSLog(@"Delegate received notification of Simplestyle loading failure - (%@)",error?error:@"");
}


@end
