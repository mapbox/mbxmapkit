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
#import "MBXPointAnnotation.h"
#import "MBXOfflineMapDownloader.h"
#import "MBXOfflineMapDatabase.h"


@interface MBXxViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;
@property (nonatomic) UIActionSheet *actionSheet;

@property (weak, nonatomic) IBOutlet UIView *offlineMapProgressView;
@property (weak, nonatomic) IBOutlet UIProgressView *offlineMapProgress;
@property (weak, nonatomic) IBOutlet UIView *offlineMapDownloadControlsView;
@property (weak, nonatomic) IBOutlet UIButton *offlineMapButtonHelp;
@property (weak, nonatomic) IBOutlet UIButton *offlineMapButtonBegin;
@property (weak, nonatomic) IBOutlet UIButton *offlineMapButtonCancel;
@property (weak, nonatomic) IBOutlet UIButton *offlineMapButtonSuspendResume;

@property (nonatomic) BOOL viewHasFinishedLoading;

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
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:memoryCapacity diskCapacity:diskCapacity diskPath:nil];
    //[urlCache removeAllCachedResponses];
    [NSURLCache setSharedURLCache:urlCache];

    // Start with the offline map download progress and controls hidden (progress will be shownn from elsewhere as needed)
    //
    _offlineMapProgressView.hidden = YES;
    _offlineMapDownloadControlsView.hidden = YES;
    [[MBXOfflineMapDownloader sharedOfflineMapDownloader] setDelegate:self];

    // Configure the mapView to use delegate callbacks for managing tile overlay layers, map centering, and adding
    // adding markers.
    //
    _mapView.rotateEnabled = NO;
    _mapView.pitchEnabled = NO;
    _mapView.delegate = self;

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
    _rasterOverlay.delegate = self;
    [_mapView addOverlay:_rasterOverlay];

    // This enables us to assert that delegate callbacks aren't getting called before initialization is complete
    //
    _viewHasFinishedLoading = YES;
}


#pragma mark - Things for switching between maps

- (UIActionSheet *)universalActionSheet
{
    // This is the list of options for selecting which map should be shown by the demo app
    //
    return [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"cancel" destructiveButtonTitle:nil otherButtonTitles:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", @"Offline Map Downloader", @"Offline Map Viewer", nil];
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
    // Reset the MKMapView to some reasonable defaults.
    //
    _mapView.mapType = MKMapTypeStandard;
    _mapView.scrollEnabled = YES;
    _mapView.zoomEnabled = YES;
    _offlineMapDownloadControlsView.hidden = YES;

    // Make sure that any downloads (tiles, metadata, marker icons) which might be in progress for
    // the old tile overlay are stopped, and remove the overlay and its markers from the MKMapView.
    // The invalidation step is necessary to avoid the possibility of visual glitching or crashes due to
    // delegate callbacks or asynchronous completion handlers getting invoked for downloads which might
    // be still in progress.
    //
    [_mapView removeAnnotations:_rasterOverlay.markers];
    [_mapView removeOverlay:_rasterOverlay];
    [_rasterOverlay invalidateAndCancel];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}


#pragma mark - UIActionSheetDelegate protocol implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // This switches between maps in response to action sheet selections
    //
    switch(buttonIndex) {
        case 0:
            // OSM world map
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 1:
            // OSM over Apple satellite
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.mapType = MKMapTypeSatellite;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-9tlo4knw" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 2:
            // Terrain under Apple labels
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-mf07hryq" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
            break;
        case 3:
            // Tilemill bounded region (scroll & zoom limited to programmatic control only)
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.scrollEnabled = NO;
            _mapView.zoomEnabled = NO;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.NACIS2012" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 4:
            // Tilemill region over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.clp-2011-11-03-1200" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 5:
            // Tilemill transparent over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.pdx_meters" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 6:
            // Offline Map Downloader
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm" metadata:YES markers:NO];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            _offlineMapDownloadControlsView.hidden = NO;
            [self offlineMapDownloader:[MBXOfflineMapDownloader sharedOfflineMapDownloader] stateChangedTo:[[MBXOfflineMapDownloader sharedOfflineMapDownloader] state]];
            break;
        case 7:
            // Offline Map Viewer
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithOfflineMapDatabase:[MBXOfflineMapDownloader sharedOfflineMapDownloader].offlineMapDatabases.lastObject];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
    }
}


#pragma mark - Offline map download controls

- (IBAction)offlineMapButtonActionHelp:(id)sender
{
    NSString *title = @"Offline Map Downloader Help";
    NSString *message = @"Arrange the map to show the region you want to download for offline use, then press [Begin]. [Suspend] stops the downloading in such a way that you can [Resume] it later. [Cancel] stops the download and discards the partially downloaded files.";
    UIAlertView *help = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [help show];
}


- (IBAction)offlineMapButtonActionBegin:(id)sender
{
    [[MBXOfflineMapDownloader sharedOfflineMapDownloader] beginDownloadingMapID:_rasterOverlay.mapID mapRegion:_mapView.region minimumZ:_rasterOverlay.minimumZ maximumZ:_rasterOverlay.maximumZ];
}


- (IBAction)offlineMapButtonActionCancel:(id)sender
{
    NSString *title = @"Are you sure you want to cancel?";
    NSString *message = @"Canceling an offline map download permanently deletes its partially downloaded map data. This action cannot be undone.";
    UIAlertView *areYouSure = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
    [areYouSure show];
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // For the are you sure you want to cancel alert dialog, do the cancel action if the answer was "Yes"
    //
    if([alertView.title isEqualToString:@"Are you sure you want to cancel?"])
    {
        if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
        {
            [[MBXOfflineMapDownloader sharedOfflineMapDownloader] cancel];
        }
    }
}


- (IBAction)offlineMapButtonActionSuspendResume:(id)sender {
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
    assert(_viewHasFinishedLoading);

    switch (state)
    {
        case MBXOfflineMapDownloaderStateAvailable:
            _offlineMapButtonBegin.enabled = YES;
            _offlineMapButtonCancel.enabled = NO;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend" forState:UIControlStateNormal];
            _offlineMapButtonSuspendResume.enabled = NO;
            break;
        case MBXOfflineMapDownloaderStateRunning:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = YES;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend" forState:UIControlStateNormal];
            _offlineMapButtonSuspendResume.enabled = YES;
            break;
        case MBXOfflineMapDownloaderStateCanceling:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = NO;
            [_offlineMapButtonSuspendResume setTitle:@"Suspend" forState:UIControlStateNormal];
            _offlineMapButtonSuspendResume.enabled = NO;
            break;
        case MBXOfflineMapDownloaderStateSuspended:
            _offlineMapButtonBegin.enabled = NO;
            _offlineMapButtonCancel.enabled = YES;
            [_offlineMapButtonSuspendResume setTitle:@"Resume" forState:UIControlStateNormal];
            _offlineMapButtonSuspendResume.enabled = YES;
            break;
    }
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite
{
    assert([NSThread isMainThread]);
    assert(_viewHasFinishedLoading);

    [_offlineMapProgress setProgress:0.0 animated:NO];
    _offlineMapProgressView.hidden = NO;
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite
{
    assert([NSThread isMainThread]);
    assert(_viewHasFinishedLoading);

    if (totalFilesExpectedToWrite != 0)
    {
        float progress = ((float)totalFilesWritten) / ((float)totalFilesExpectedToWrite);
        [_offlineMapProgress setProgress:progress animated:YES];
    }
}

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error
{
    assert([NSThread isMainThread]);
    assert(_viewHasFinishedLoading);

    _offlineMapProgressView.hidden = YES;
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


#pragma mark - MBXRasterTileOverlayDelegate implementation

- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMetadata:(NSDictionary *)metadata withError:(NSError *)error
{
    assert(_mapView);
    assert([NSThread isMainThread]);

    // This delegate callback is for centering the map once the map metadata has been loaded
    //
    if (error)
    {
        NSLog(@"Failed to load metadata for map ID %@ - (%@)", overlay.mapID, error?error:@"");
    }
    else
    {
        MKCoordinateRegion region = MKCoordinateRegionMake(overlay.center, MKCoordinateSpanMake(0, 360 / pow(2, overlay.centerZoom) * _mapView.frame.size.width / 256));
        
        [_mapView setRegion:region animated:NO];
    }
}


- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error
{
    assert(_mapView);
    assert([NSThread isMainThread]);

    // This delegate callback is for adding map markers to an MKMapView once all the markers for the tile overlay have loaded
    //
    if (error)
    {
        NSLog(@"Failed to load markers for map ID %@ - (%@)", overlay.mapID, error?error:@"");
    }
    else
    {
        [_mapView addAnnotations:markers];
    }
}

- (void)tileOverlayDidFinishLoadingMetadataAndMarkersForOverlay:(MBXRasterTileOverlay *)overlay
{
    assert([NSThread isMainThread]);

    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
