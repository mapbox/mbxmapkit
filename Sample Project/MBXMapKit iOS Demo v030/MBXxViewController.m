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
    // Show the network activity spinner
    //
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

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


#pragma mark - UIActionSheetDelegate protocol implementation

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // This switches between maps in response to action sheet selections
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
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
