//
//  MBXViewController.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MBXViewController.h"

#import "MBXMapKit.h"

@implementation MBXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // iOS project shows use via programmatic view API
    //
#ifdef MBXMAPKIT_ENABLE_SIMPLESTYLE_MAKI
#warning This mapID needs to be changed to justin.{{something}}, where something is a map which has some point markers.
    // This map is configured with some markers for testing the implementation of mapbox/mbxmapkit issue #9 (simplestyle)
    //
    MBXMapView *mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"wsnook.h0bg05jd"];
    [self.view addSubview:mapView];
    
    // And now here is a bonus marker to demonstrate the fix for mapbox/mbxmapkit issue #5 (Maki markers)
    // The addMakiMarkerSize:symbol:color:toMapView: approach is intended to directly reflect the fact that the
    // marker images are coming from the MapBox Core API: https://www.mapbox.com/developers/api/#Stand-alone.markers
    // Implementing any shortcut constants along the lines of `pin.pinImageID = MBXPinImageBus;` would have the
    // disadvantage of requiring a code change (add a new constant) any time a new Maki icon is added.
    //
    MBXSimpleStylePointAnnotation *marker = [[MBXSimpleStylePointAnnotation alloc] init];
    marker.title = @"National Gallery of Art";
    [marker setCoordinate:CLLocationCoordinate2DMake(38.89116,-77.01942)];
    [marker addMakiMarkerSize:@"large" symbol:@"art-gallery" color:@"#f86767" toMapView:mapView];

#else
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
#endif
}

@end