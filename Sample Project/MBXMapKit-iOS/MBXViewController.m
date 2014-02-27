//
//  MBXViewController.m
//  MBXMapKit
//
//  Created by Justin R. Miller on 9/4/13.
//  Copyright (c) 2013-2014 Mapbox. All rights reserved.
//

#import "MBXViewController.h"

#import "MBXMapKit.h"

@implementation MBXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Programmatic iOS example: use example map which includes simplestyle markers
    //
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"examples.map-pgygbwdm"]];
}

@end