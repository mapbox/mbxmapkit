//
//  MBXViewController.m
//  MBXMapKit iOS Demo v030
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXViewController.h"
#import "MBXMapKit.h"

@interface MBXViewController ()

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
@property (weak, nonatomic) IBOutlet UIView *removeOfflineMapsView;


@property (nonatomic) BOOL viewHasFinishedLoading;
@property (nonatomic) BOOL currentlyViewingAnOfflineMap;

@end

@implementation MBXViewController


#pragma mark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the Mapbox access token for API access
    //
    [MBXMapKit setAccessToken:@"pk.eyJ1IjoianVzdGluIiwiYSI6IlpDbUJLSUEifQ.4mG8vhelFMju6HpIY-Hi5A"];

    // Configure the amount of storage to use for NSURLCache's shared cache: You can also omit this and allow NSURLCache's
    // to use its default cache size. These sizes determines how much storage will be used for performance caching of HTTP
    // requests made by MBXOfflineMapDownloader and MBXRasterTileOverlay. Please note that these values apply only to the
    // HTTP cache, and persistent offline map data is stored using an entirely separate mechanism.
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
    _removeOfflineMapsView.hidden = YES;

    // Let the shared offline map downloader know that we want to be notified of changes in its state. This will allow us to
    // update the download progress indicator and the begin/cancel/suspend/resume buttons
    //
    MBXOfflineMapDownloader *sharedDownloader = [MBXOfflineMapDownloader sharedOfflineMapDownloader];
    [sharedDownloader setDelegate:self];

    // Turn off distracting MKMapView features which aren't relevant to this demonstration
    _mapView.showsBuildings = NO;
    _mapView.rotateEnabled = NO;
    _mapView.pitchEnabled = NO;

    // Let the mapView know that we want to use delegate callbacks to provide customized renderers for tile overlays and views
    // for annotations. In order to make use of MBXRasterTileOverlay and MBXPointAnnotation, it is essential for your app to set
    // this delegate and implement MKMapViewDelegate's mapView:rendererForOverlay: and mapView:(MKMapView *)mapView viewForAnnotation:
    // methods.
    //
    _mapView.delegate = self;

    // Show the network activity spinner in the status bar
    //
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

    // Configure a raster tile overlay to use the initial sample map
    //
    _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];

    // Let the raster tile overlay know that we want to be notified when it has asynchronously loaded the sample map's metadata
    // (so we can set the map's center and zoom) and the sample map's markers (so we can add them to the map).
    //
    _rasterOverlay.delegate = self;

    // Add the raster tile overlay to our mapView so that it will immediately start rendering tiles. At this point the MKMapView's
    // default center and zoom don't match the center and zoom of the sample map, but that's okay. Adding the layer now will prevent
    // a percieved visual glitch in the UI (an empty map), and we'll fix the center and zoom when tileOverlay:didLoadMetadata:withError:
    // gets called to notify us that the raster tile overlay has finished asynchronously loading its metadata.
    //
    [_mapView addOverlay:_rasterOverlay];

    // If there was a suspended offline map download, resume it...
    // Note how the call above to initialize the shared map downloader happens before its delegate can be set. So now, in order
    // to know whether there might be a suspended download which was restored from disk, we need to poll and invoke any
    // necessary handler functions on our own.
    //
    if(sharedDownloader.state == MBXOfflineMapDownloaderStateSuspended)
    {
        [self offlineMapDownloader:sharedDownloader stateChangedTo:MBXOfflineMapDownloaderStateSuspended];
        [self offlineMapDownloader:sharedDownloader totalFilesExpectedToWrite:sharedDownloader.totalFilesExpectedToWrite];
        [self offlineMapDownloader:sharedDownloader totalFilesWritten:sharedDownloader.totalFilesWritten totalFilesExpectedToWrite:sharedDownloader.totalFilesExpectedToWrite];
        [[MBXOfflineMapDownloader sharedOfflineMapDownloader] resume];
    }
}


#pragma mark - Things for switching between maps

- (UIActionSheet *)universalActionSheet
{
    // This is the list of options for selecting which map should be shown by the demo app
    //
    return [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"World baselayer, no Apple",@"World overlay, Apple satellite",@"World baselayer, Apple labels",@"Regional baselayer, no Apple",@"Regional overlay, Apple streets",@"Alpha overlay, Apple streets", @"Offline map downloader", @"Offline map viewer", @"Show attribution",nil];
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
    _removeOfflineMapsView.hidden = YES;

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
    _currentlyViewingAnOfflineMap = NO;
}


#pragma mark - UIActionSheetDelegate protocol implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // This switches between maps in response to action sheet selections
    //
    switch(buttonIndex) {
        case 0:
        {
            // OSM world map
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm"];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
        }
        case 1:
        {
            // OSM over Apple satellite
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.mapType = MKMapTypeSatellite;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-9tlo4knw" includeMetadata:YES includeMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        }
        case 2:
        {
            // Terrain under Apple labels
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.map-mf07hryq" includeMetadata:YES includeMarkers:NO];
            _rasterOverlay.delegate = self;
            [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
            break;
        }
        case 3:
        {
            // Tilemill bounded region (scroll & zoom limited to programmatic control only)
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.scrollEnabled = NO;
            _mapView.zoomEnabled = NO;
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.NACIS2012" includeMetadata:YES includeMarkers:NO];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            break;
        }
        case 4:
        {
            // Tilemill region over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.clp-2011-11-03-1200" includeMetadata:YES includeMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        }
        case 5:
        {
            // Tilemill transparent over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"justin.pdx_meters" includeMetadata:YES includeMarkers:NO];
            _rasterOverlay.delegate = self;
            _rasterOverlay.canReplaceMapContent = NO;
            [_mapView addOverlay:_rasterOverlay];
            break;
        }
        case 6:
        {
            // Offline Map Downloader
            [self resetMapViewAndRasterOverlayDefaults];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
            _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithMapID:@"examples.map-pgygbwdm" includeMetadata:YES includeMarkers:YES];
            _rasterOverlay.delegate = self;
            [_mapView addOverlay:_rasterOverlay];
            _offlineMapDownloadControlsView.hidden = NO;
            [self offlineMapDownloader:[MBXOfflineMapDownloader sharedOfflineMapDownloader] stateChangedTo:[[MBXOfflineMapDownloader sharedOfflineMapDownloader] state]];
            break;
        }
        case 7:
        {
            // Offline Map Viewer
            [self resetMapViewAndRasterOverlayDefaults];
            _currentlyViewingAnOfflineMap = YES;
            MBXOfflineMapDatabase *offlineMap = [[[MBXOfflineMapDownloader sharedOfflineMapDownloader] offlineMapDatabases] lastObject];
            if (offlineMap)
            {
                _rasterOverlay = [[MBXRasterTileOverlay alloc] initWithOfflineMapDatabase:offlineMap];
                _rasterOverlay.delegate = self;
                _removeOfflineMapsView.hidden = NO;

                [_mapView addOverlay:_rasterOverlay];
            }
            else
            {
                [[[UIAlertView alloc] initWithTitle:@"No Offline Maps"
                                            message:@"No offline maps have been downloaded."
                                           delegate:nil
                                  cancelButtonTitle:nil
                                  otherButtonTitles:@"OK", nil] show];
            }
            break;
        }
        case 8:
        {
            // Show Attribution
            [self attribution:_rasterOverlay.attribution];
            break;
        }
    }
}


#pragma mark - AlertView stuff

- (void)areYouSureYouWantToDeleteAllOfflineMaps
{
    NSString *title = @"Are you sure you want to remove your offline maps?";
    NSString *message = @"This will permently delete your offline map data. This action cannot be undone.";
    UIAlertView *areYouSure = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
    [areYouSure show];
}

- (void)areYouSureYouWantToCancel
{
    NSString *title = @"Are you sure you want to cancel?";
    NSString *message = @"Canceling an offline map download permanently deletes its partially downloaded map data. This action cannot be undone.";
    UIAlertView *areYouSure = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:@"No", @"Yes", nil];
    [areYouSure show];
}

- (void)attribution:(NSString *)attribution
{
    NSString *title = @"Attribution";
    NSString *message = attribution;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Mapbox Details", @"OSM Details", nil];
    [alert show];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if([alertView.title isEqualToString:@"Are you sure you want to cancel?"])
    {
        // For the are you sure you want to cancel alert dialog, do the cancel action if the answer was "Yes"
        //
        if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
        {
            [[MBXOfflineMapDownloader sharedOfflineMapDownloader] cancel];
        }
    }
    else if([alertView.title isEqualToString:@"Are you sure you want to remove your offline maps?"])
    {
        // For are you sure you want to remove offline maps alert dialog, do the remove action if the answer was "Yes"
        //
        if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Yes"])
        {
            if(_currentlyViewingAnOfflineMap)
            {
                [self resetMapViewAndRasterOverlayDefaults];
            }
            for(MBXOfflineMapDatabase *db in [MBXOfflineMapDownloader sharedOfflineMapDownloader].offlineMapDatabases)
            {
                [[MBXOfflineMapDownloader sharedOfflineMapDownloader] removeOfflineMapDatabase:db];
            }

        }
    }
    else if([alertView.title isEqualToString:@"Attribution"])
    {
        // For the attribution alert dialog, open the Mapbox and OSM copyright pages when their respective buttons are pressed
        //
        if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Mapbox Details"])
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://www.mapbox.com/tos/"]];
        }
        if([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"OSM Details"])
        {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.openstreetmap.org/copyright"]];
        }
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
    [[MBXOfflineMapDownloader sharedOfflineMapDownloader] beginDownloadingMapID:_rasterOverlay.mapID mapRegion:_mapView.region minimumZ:_rasterOverlay.minimumZ maximumZ:MIN(16,_rasterOverlay.maximumZ)];
}


- (IBAction)offlineMapButtonActionCancel:(id)sender
{
    [self areYouSureYouWantToCancel];
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


- (IBAction)removeOfflineMapsButtonAction:(id)sender {
    // Remove offline maps
    //
    [self areYouSureYouWantToDeleteAllOfflineMaps];
}


#pragma mark - MBXOfflineMapDownloaderDelegate implementation (progress indicator, etc)

- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader stateChangedTo:(MBXOfflineMapDownloaderState)state
{
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
    [_offlineMapProgress setProgress:0.0 animated:NO];
    _offlineMapProgressView.hidden = NO;
}


- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader totalFilesWritten:(NSUInteger)totalFilesWritten totalFilesExpectedToWrite:(NSUInteger)totalFilesExpectedToWrite
{
    if (totalFilesExpectedToWrite != 0)
    {
        float progress = ((float)totalFilesWritten) / ((float)totalFilesExpectedToWrite);
        [_offlineMapProgress setProgress:progress animated:YES];
    }
}


- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didEncounterRecoverableError:(NSError *)error
{
    if(error.code == MBXMapKitErrorCodeURLSessionConnectivity)
    {
        // For some reason the offline map downloader wasn't able to make an HTTP connection. This probably means there is a
        // network connectivity problem, so stop trying to download stuff. Please note how this is a minimal example which probably isn't
        // very suitable to copy over into real apps. In contexts where there is a reasonable expectation of intermittent network
        // connectivity, an approach with some capability to resume when the network re-connects would probably be better.
        //
        [offlineMapDownloader suspend];
        NSLog(@"The offline map download was suspended in response to a network connectivity error: %@",error);
    }
    else if(error.code == MBXMapKitErrorCodeHTTPStatus)
    {
        // The HTTP status response for one of the urls requested by the offline map came back as something other than 200. This is
        // not necessarily bad, but it probably indicates a problem with the parameters used to begin an offline map download. For
        // example, you might have requested markers for a map that doesn't have any.
        //
        NSLog(@"The offline map downloader encountered an HTTP status error: %@",error);
    }
    else if(error.code == MBXMapKitErrorCodeOfflineMapSqlite)
    {
        // There was an sqlite error with the offline map. The most likely explanation is that the disk is running out of space.
        //
        NSLog(@"The offline map downloader encountered an sqlite error: %@",error);
    }
}


- (void)offlineMapDownloader:(MBXOfflineMapDownloader *)offlineMapDownloader didCompleteOfflineMapDatabase:(MBXOfflineMapDatabase *)offlineMapDatabase withError:(NSError *)error
{
    _offlineMapProgressView.hidden = YES;

    if(error)
    {
        if(error.code == MBXMapKitErrorCodeDownloadingCanceled)
        {
            // Ignore cancellations,
        }
        else
        {
            // ...but pay attention to other errors
            //
            NSLog(@"The offline map download completed with an error: %@",error);
        }
    }
}


#pragma mark - MKMapViewDelegate protocol implementation

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    // This is boilerplate code to connect tile overlay layers with suitable renderers
    //
    if ([overlay isKindOfClass:[MBXRasterTileOverlay class]])
    {
        MBXRasterTileRenderer *renderer = [[MBXRasterTileRenderer alloc] initWithTileOverlay:overlay];
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
    // This delegate callback is for centering the map once the map metadata has been loaded
    //
    if (error)
    {
        NSLog(@"Failed to load metadata for map ID %@ - (%@)", overlay.mapID, error?error:@"");
    }
    else
    {
        [_mapView mbx_setCenterCoordinate:overlay.center zoomLevel:overlay.centerZoom animated:NO];
    }
}


- (void)tileOverlay:(MBXRasterTileOverlay *)overlay didLoadMarkers:(NSArray *)markers withError:(NSError *)error
{
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

- (void)tileOverlayDidFinishLoadingMetadataAndMarkers:(MBXRasterTileOverlay *)overlay
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
