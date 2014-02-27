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

@property (nonatomic) MBXMapView *mapView;

@end


@implementation MBXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Programmatic iOS example: use example map which includes simplestyle markers
    //
    _mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"examples.map-pgygbwdm"];

    // In addition to the markers included with the map, add another marker with a custom icon (from the Mapbox Core API)
    //
    MBXPointAnnotation *marker = [[MBXPointAnnotation alloc] init];
    marker.title = @"Santa Cruz Harbor";
    [marker setCoordinate:CLLocationCoordinate2DMake(36.96069, -122.01516)];
    [marker addMarkerSize:@"large" symbol:@"harbor" color:@"#f86767" toMapView:_mapView];

    [self.view addSubview:_mapView];
}

@end