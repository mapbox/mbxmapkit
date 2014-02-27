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
    self.mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"examples.map-pgygbwdm"];

    // In addition to the markers included with the map, add another marker with a custom icon from the Mapbox API
    //
    MBXPointAnnotation *marker = [MBXPointAnnotation new];
    marker.title = @"Santa Cruz Harbor";
    marker.coordinate = CLLocationCoordinate2DMake(36.96069, -122.01516);
    [marker addMarkerSize:@"large" symbol:@"harbor" color:@"#f86767" toMapView:self.mapView];

    // Add the map to the view hierarchy.
    //
    [self.view addSubview:self.mapView];
}

@end