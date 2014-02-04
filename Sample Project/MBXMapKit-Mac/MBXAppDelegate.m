//
//  MBXAppDelegate.m
//  MBXMapKit Mac
//
//  Created by Justin R. Miller on 9/13/13.
//  Copyright (c) 2013 MapBox. All rights reserved.
//

#import "MBXAppDelegate.h"

#import "MBXMapKit.h"

@interface MBXAppDelegate ()

@property (nonatomic) IBOutlet MBXMapView *mapView;

@end

@implementation MBXAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
#ifdef MBXMAPKIT_ENABLE_MBTILES_WITH_LIBSQLITE3
    NSLog(@"Can somebody with a Mac Developer program membership figure out if the mbtiles stuff works here?");
#else
    // Mac project shows use via XIB
    //
    self.mapView.mapID = @"justin.map-pgygbwdm";
#endif
}

@end