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
@property (weak) IBOutlet NSProgressIndicator *networkInUseSpinner;

@property (weak) IBOutlet NSButton *offlineMapButtonBegin;
@property (weak) IBOutlet NSButton *offlineMapButtonCancel;
@property (weak) IBOutlet NSButton *offlineMapButtonSuspendResume;
@property (weak) IBOutlet NSProgressIndicator *offlineMapProgress;

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


    // Configure the mapView to use delegate callbacks for managing tile overlay layers, map centering, and adding
    // adding markers.
    //
    _mapView.rotateEnabled = NO;
    _mapView.pitchEnabled = NO;
    _mapView.delegate = self;

    [_networkInUseSpinner startAnimation:self];
    _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
    _rasterOverlay.delegate = self;
    [_mapView addOverlay:_rasterOverlay];

    // Configure the popup button for selecting which map to show
    //
    NSArray *titles = [NSArray arrayWithObjects:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", @"Offline Map Downloader", @"Offline Map Viewer", nil];
    [_popupButton removeAllItems];
    [_popupButton addItemsWithTitles:titles];


    // Configure the offline map download controls and progress bar
    [_offlineMapButtonBegin setHidden:YES];
    [_offlineMapButtonCancel setHidden:YES];
    [_offlineMapButtonSuspendResume setHidden:YES];
    [_offlineMapProgress setHidden:YES];
    [[MBXOfflineMapDownloader sharedOfflineMapDownloader] setDelegate:self];
    [_offlineMapProgress setMinValue:0.0];
    [_offlineMapProgress setMaxValue:1.0];
    [_offlineMapProgress setDoubleValue:0.0];
}


#pragma mark - Things for switching between maps

- (void)resetMapViewAndRasterOverlayDefaults
{
    // Start the progress spinner
    //
    [_networkInUseSpinner startAnimation:self];

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

    // Hide offline map download controls
    [_offlineMapButtonBegin setHidden:YES];
    [_offlineMapButtonCancel setHidden:YES];
    [_offlineMapButtonSuspendResume setHidden:YES];
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
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-9tlo4knw" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 2:
                // Terrain under Apple labels
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-mf07hryq" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
                break;
            case 3:
                // Tilemill bounded region (scroll & zoom limited to programmatic control only)
                [self resetMapViewAndRasterOverlayDefaults];
                _mapView.scrollEnabled = NO;
                _mapView.zoomEnabled = NO;
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.NACIS2012" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 4:
                // Tilemill region over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.clp-2011-11-03-1200" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 5:
                // Tilemill transparent over Apple
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.pdx_meters" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                _rasterOverlay.canReplaceMapContent = NO;
                [_mapView addOverlay:_rasterOverlay];
                break;
            case 6:
                // Offline Map Downloader
                [self resetMapViewAndRasterOverlayDefaults];
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm" includeMetadata:YES includeMarkers:NO];
                _rasterOverlay.delegate = self;
                [_mapView addOverlay:_rasterOverlay];
                [_offlineMapButtonBegin setHidden:NO];
                [_offlineMapButtonCancel setHidden:NO];
                [_offlineMapButtonSuspendResume setHidden:NO];
                [self offlineMapDownloader:[MBXOfflineMapDownloader sharedOfflineMapDownloader] stateChangedTo:[[MBXOfflineMapDownloader sharedOfflineMapDownloader] state]];
                break;
            case 7:
                // Offline Map Viewer
                [self resetMapViewAndRasterOverlayDefaults];
                break;
        }
    }
}


#pragma mark - Offline map download controls

- (IBAction)beginButtonAction:(NSButton *)sender {
    [[MBXOfflineMapDownloader sharedOfflineMapDownloader] beginDownloadingMapID:_rasterOverlay.mapID mapRegion:_mapView.region minimumZ:_rasterOverlay.minimumZ maximumZ:_rasterOverlay.maximumZ];
}


- (IBAction)cancelButtonAction:(NSButton *)sender {
    NSString *title = @"Are you sure you want to cancel?";
    NSString *message = @"Canceling an offline map download permanently deletes its partially downloaded map data. This action cannot be undone.";
    NSAlert *areYouSure = [NSAlert alertWithMessageText:title defaultButton:@"No" alternateButton:@"Yes" otherButton:nil informativeTextWithFormat:message,nil];
    [areYouSure setAlertStyle:NSWarningAlertStyle];
    if([areYouSure runModal] == NSAlertAlternateReturn)
    {
        // Alternate choice = "yes, I'm sure I want to cancel"
        [[MBXOfflineMapDownloader sharedOfflineMapDownloader] cancel];
    }
}


- (IBAction)suspendResumeButtonAction:(NSButton *)sender {
    if ([[MBXOfflineMapDownloader sharedOfflineMapDownloader] state] == MBXOfflineMapDownloaderStateSuspended)
    {
        [[MBXOfflineMapDownloader sharedOfflineMapDownloader] resume];
    }
    else
    {
        [[MBXOfflineMapDownloader sharedOfflineMapDownloader] suspend];
    }
}


#pragma mark - Offline map progress indicator

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader stateChangedTo:(MBXOfflineMapDownloaderState)state
{
    assert([NSThread isMainThread]);

    switch (state)
    {
        case MBXOfflineMapDownloaderStateAvailable:
            _offlineMapButtonBegin.enabled = YES;
            _offlineMapButtonCancel.enabled = NO;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend"];
            _offlineMapButtonSuspendResume.enabled = NO;
            break;
        case MBXOfflineMapDownloaderStateRunning:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = YES;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend"];
            _offlineMapButtonSuspendResume.enabled = YES;
            break;
        case MBXOfflineMapDownloaderStateCanceling:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = NO;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend"];
            _offlineMapButtonSuspendResume.enabled = NO;
            break;
        case MBXOfflineMapDownloaderStateSuspended:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = YES;
            [_offlineMapButtonSuspendResume setTitle:@"Resume"];
            _offlineMapButtonSuspendResume.enabled = YES;
            break;
    }
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite
{
    assert([NSThread isMainThread]);

    [_offlineMapProgress setDoubleValue:0.0];
    [_offlineMapProgress setHidden:NO];
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite
{
    assert([NSThread isMainThread]);

    if (totalFilesExpectedToWrite != 0)
    {
        float progress = ((float)totalFilesWritten) / ((float)totalFilesExpectedToWrite);
        [_offlineMapProgress setDoubleValue:progress];
    }
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error
{
    assert([NSThread isMainThread]);

    [_offlineMapProgress setHidden:YES];
}



#pragma mark - MKMapViewDelegate protocol implementation

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

- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error
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


- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error
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

- (void)tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:(MBXRasterTileOverlay *)overlay
{
    [_networkInUseSpinner stopAnimation:self];
}


@end
