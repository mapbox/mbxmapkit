//
//  MBXzAppDelegate.m
//  MBXMapKit Mac Demo v030
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXzAppDelegate.h"
#import <MapKit/MapKit.h>
#import "MBXStandardDelegate.h"
#import "MBXSimplestyle.h"
#import "MBXRasterTileOverlay.h"
#import "MBXCacheManager.h"


@interface MBXzAppDelegate ()

@property (weak) IBOutlet NSPopUpButton *popupButton;
@property (weak) IBOutlet MKMapView *mapView;
@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;
@property (nonatomic) MBXSimplestyle *simplestyle;
@property (nonatomic) MBXStandardDelegate *standardDelegate;


@end

@implementation MBXzAppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    // Initialize the mapView here rather than in applicationDidFinishLaunching: in order to avoid
    // a delay which can let Apple's map show briefly while the Mapbox layer gets added
    //
    
    //[[MBXCacheManager sharedCacheManager] clearEntireCache];

    // Configure the mapView to use boilerplate delegate callbacks for managing tile overlay layers,
    // TileJSON map centering, and adding simplestyle markers. To customize your app, you can subclass
    // or replace the MBXStandardDelegate instance.
    //
    _standardDelegate = [[MBXStandardDelegate alloc] init];
    _standardDelegate.mapView = _mapView;
    _mapView.delegate = _standardDelegate;

    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.delegate = _standardDelegate;
    _rasterOverlay.mapID = @"examples.map-pgygbwdm";

    _simplestyle = [[MBXSimplestyle alloc] init];
    _simplestyle.delegate = _standardDelegate;
    _simplestyle.mapID = @"examples.map-pgygbwdm";

    [_mapView addOverlay:_rasterOverlay];

    // Configure the popup button for selecting which map to show
    //
    NSArray *titles = [NSArray arrayWithObjects:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", nil];
    [_popupButton removeAllItems];
    [_popupButton addItemsWithTitles:titles];
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
    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.delegate = _standardDelegate;

    // Set up a new simplestyle object to account for the possibility that there are still point icons being downloaded
    //
    _simplestyle.delegate = nil;
    [_mapView removeAnnotations:_mapView.annotations];
    _simplestyle = [[MBXSimplestyle alloc] init];
    _simplestyle.delegate = _standardDelegate;

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


@end
