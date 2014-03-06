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
}



@end
