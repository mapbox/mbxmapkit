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
    // This map has some markers for testing with
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"wsnook.h0bg05jd"]];
#else
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
#endif
}

@end