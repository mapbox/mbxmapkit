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
    // Using MBTiles offline maps is slightly more complicated than using an online map with a MapBox map ID.
    // If you want to use MBTiles maps, please refer to the comments about MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    // near the top of MBXMapKit.h.
    
    // This build target is already linked to libsqlite3, and it already includes WorldMapZoom0to4.mbtiles (a small
    // world map) as a bundle resource. All we need to do to set up an opaque world map tile overlay is find
    // the path in the bundle and pass it to initWithFrame:mbtilesPath:.
    NSString *mbtilesPath = [[NSBundle mainBundle] pathForResource:@"WorldMapZoom0to4" ofType:@"mbtiles"];
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mbtilesPath:mbtilesPath]];
        
#else
    // iOS project shows use via programmatic view API
    //
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
    
#endif
}

@end