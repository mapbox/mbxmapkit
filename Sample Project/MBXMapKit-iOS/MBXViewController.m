//
//  MBXViewController.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013-2014 Mapbox. All rights reserved.
//

#import "MBXViewController.h"

#import "MBXMapKit.h"

@interface MBXViewController ()
@property (nonatomic) MBXMapViewTileOverlay *overlay;
@property (nonatomic) MBXMapView *mapView;
@property (assign) BOOL overlayVisible;
@end

@implementation MBXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    int whichDemo = 0;
    switch(whichDemo) {
        case 0:
            [self genericDemo];
            break;
        case 1:
            [self toggleBetweenMapsDemo];
            break;
    }
}

- (void)genericDemo
{
    // iOS project shows use via programmatic view API
    //
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
}

- (void)toggleBetweenMapsDemo
{
    // This demonstrates how to toggle a Mapbox mapID based tile overlay layer on and off. The visual effect is that
    // the map switches between a Mapbox map and an Apple map at 5 second intervals
    //
    _mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"];
    [self.view addSubview:_mapView];
    _overlayVisible = YES;
    
    [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(toggle:) userInfo:nil repeats:YES];
    NSLog(@"wait for it...");
}

- (void)toggle:(NSTimer *)timer
{
    if(_overlayVisible) {
        NSLog(@"toggle: hiding layer");
        // Grab a reference to the MBXMapViewTileOverlay created by initWithFrame:mapID since the MBXMapKit API doesn't
        // yet provide a way to create such layers individually
        //
        _overlay = [[_mapView overlays] lastObject];
        [_mapView removeOverlay:_overlay];
    } else {
        NSLog(@"toggle: showing layer");
        [_mapView addOverlay:_overlay];
    }
    _overlayVisible = !_overlayVisible;
}
@end