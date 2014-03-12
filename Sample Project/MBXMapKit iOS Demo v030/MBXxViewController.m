//
//  MBXxViewController.m
//  MBXMapKit iOS Demo v030
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXxViewController.h"
#import <MapKit/MapKit.h>
#import "MBXRasterTileOverlay.h"

@interface MBXxViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;
@property (nonatomic) UIActionSheet *actionSheet;

@property (nonatomic) NSInteger cacheHitCount;
@property (nonatomic) NSInteger httpSuccessCount;
@property (nonatomic) NSInteger httpFailureCount;
@property (nonatomic) NSInteger networkFailureCount;
@property (nonatomic) BOOL showStatisticsLog;

@end

@implementation MBXxViewController


#pragma mark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the cache
    //
    NSUInteger memoryCapacity = 4 * 1024 * 1024;
    NSUInteger diskCapacity = 40 * 1024 * 1024;
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:nil];
    //[URLCache removeAllCachedResponses];
    [NSURLCache setSharedURLCache:URLCache];

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

    _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
    _rasterOverlay.delegate = self;
    [_mapView addOverlay:_rasterOverlay];
}

- (void)viewWillDisappear:(BOOL)animated
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

- (UIActionSheet *)universalActionSheet
{
    // This is the list of options for selecting which map should be shown by the demo app
    //
    return [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"cancel" destructiveButtonTitle:nil otherButtonTitles:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", nil];
}


- (IBAction)iPadInfoButtonAction:(id)sender {
    // This responds to the info button from the iPad storyboard getting pressed
    //
    if(_actionSheet.visible) {
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:YES];
        _actionSheet = nil;
    } else {
        _actionSheet = [self universalActionSheet];
        [_actionSheet showFromRect:((UIButton *)sender).frame inView:self.view animated:YES];
    }
}


- (IBAction)iPhoneInfoButtonAction:(id)sender {
    // This responds to the info button from the iPhone storyboard getting pressed
    //
    if(_actionSheet.visible) {
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:YES];
        _actionSheet = nil;
    } else {
        _actionSheet = [self universalActionSheet];
        [_actionSheet showFromRect:((UIButton *)sender).frame inView:self.view animated:YES];
    }
}


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

    _mapView.scrollEnabled = YES;
    _mapView.zoomEnabled = YES;
}


- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // Demo app: This switches between maps in response to action sheet selections
    //
    switch(buttonIndex) {
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
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-9tlo4knw" loadMetadata:YES loadMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 2:
            // Terrain under Apple labels
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-mf07hryq" loadMetadata:YES loadMarkers:NO];
            _rasterOverlay.delegate = self;
            [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
            break;
        case 3:
            // Tilemill bounded region (scroll & zoom limited to programmatic control only)
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.scrollEnabled = NO;
            _mapView.zoomEnabled = NO;
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.NACIS2012" loadMetadata:YES loadMarkers:NO];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 4:
            // Tilemill region over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.clp-2011-11-03-1200" loadMetadata:YES loadMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 5:
            // Tilemill transparent over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.pdx_meters" loadMetadata:YES loadMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
    }
}


#pragma mark - Delegate protocol implementations (customize as needed)

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
    // Show cache and network statistics each time the map finishes loading
    //
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


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata
{
    // This required delegate callback is for centering the map once the TileJSON has been loaded
    //
    if(_mapView) {
        MKCoordinateRegion region = MKCoordinateRegionMake(overlay.center, MKCoordinateSpanMake(0, 360 / pow(2, overlay.centerZoom) * _mapView.frame.size.width / 256));
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_mapView setRegion:region animated:NO];
        });
    }
    else
    {
        NSLog(@"Warning: the mapView property is not set (didLoadMetadata:)");
    }
}


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarker:(MBXPointAnnotation *)marker
{
    // This required delegate callback is for adding map markers, one at a time, to an MKMapView as soon as they are loaded
    //
    if(_mapView) {
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_mapView addAnnotation:marker];
        });
    }
    else
    {
        NSLog(@"Warning: the mapView property is not set (didLoadMarker:)");
    }
}


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailLoadingMetadataWithError:(NSError *)error
{
    // This optional delegate callback is for handling situations when something goes wrong with loading the map metadata
    //
    NSLog(@"Failed to load metadata for map ID %@ - (%@)", overlay.mapID, error?error:@"");
}


- (void)MBXRasterTileOverlay:(MBXRasterTileOverlay *)overlay didFailLoadingMarkersWithError:(NSError *)error
{
    // This optional delegate callback is for handling situations when something goes wrong with loading the map markers
    //
    NSLog(@"Failed to load markers for map ID %@ - (%@)", overlay.mapID, error?error:@"");
}


@end
