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

    
#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    // Using MBTiles offline maps is slightly more complicated than using an online map with a MapBox map ID.
    // If you want to use MBTiles maps, please refer to the comments about MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    // near the top of MBXMapKit.h.
    
    // This build target is already linked to libsqlite3, and it already includes WorldMapZoom0to4.mbtiles (a small
    // world map) as a bundle resource. All we need to do to set up an opaque world map tile overlay is find
    // the path in the bundle and pass it to initWithFrame:mbtilesPath:.
    
    NSString *mbtilesPath;
    MBXMapView *mapView;
    MBXMapViewTileOverlay *overlay;
    int whichExampleToUse = 2;
    switch(whichExampleToUse) {
        case 1:
            // This example is meant to behave similarly to the original initWithFrame:mapID: code
            // Since the MBTiles file contains a map that covers the whole world, there aren't any problems here
            // with edge case problems involving Apple's map showing up under missing tiles.
            //
            mbtilesPath = [[NSBundle mainBundle] pathForResource:@"WorldMapZoom0to4" ofType:@"mbtiles"];
            [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mbtilesPath:mbtilesPath]];
            break;
            
        case 2:
            // This example takes advantage of the MKTileOverlay API (exposed through MBXMapViewTileOverlay) to
            // exercise additional control over the map's appearance. Since the US map doesn't cover the whole world,
            // this demonstrates how to deal with edge cases involving what happens with tiles that aren't included
            // in the MBTiles file.
            //
            // The goal here is to show a map of the USA on top of an otherwise blank background. Note that
            // useWorldForBounds:YES combined with overlay.canReplaceMapContent=YES will prevent Apple's map from
            // showing up behind missing tiles.
            //
            mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds];
            mbtilesPath = [[NSBundle mainBundle] pathForResource:@"USAMapZoom0to6" ofType:@"mbtiles"];
            overlay = [[MBXMapViewTileOverlay alloc] initWithMBTilesPath:mbtilesPath useWorldForBounds:YES mapView:mapView];
            overlay.canReplaceMapContent = YES;
            [mapView addOverlay:overlay];
            [self.view addSubview:mapView];
            break;
            
        case 3:
            // This example demonstrates that, by itself, overlay.canReplaceMapContent=YES is not enough to prevent
            // Apple's map from showing up behind the MBTiles map.
            //
            mapView = [[MBXMapView alloc] initWithFrame:self.view.bounds];
            mbtilesPath = [[NSBundle mainBundle] pathForResource:@"USAMapZoom0to6" ofType:@"mbtiles"];
            overlay = [[MBXMapViewTileOverlay alloc] initWithMBTilesPath:mbtilesPath useWorldForBounds:NO mapView:mapView];
            [overlay setCanReplaceMapContent:YES];
            [mapView addOverlay:overlay];
            [self.view addSubview:mapView];
            break;
    }
    
#else
    // iOS project shows use via programmatic view API
    //
    [self.view addSubview:[[MBXMapView alloc] initWithFrame:self.view.bounds mapID:@"justin.map-pgygbwdm"]];
    
#endif
}

@end