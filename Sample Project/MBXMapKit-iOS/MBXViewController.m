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

    
#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    // Demonstrate how to add an offline MBTiles map layer by specifiying the path to an MBTiles file
    // NOTE: Please refer to the comments in MBXMapKit.h about linking to sqlite.
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mbtilesPath:@"some/path"]];
    
#else
    // iOS project shows use via programmatic view API
    //
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
    
#endif
}

@end