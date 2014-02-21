//
//  MBXAppDelegate.m
//  MBXMapKit Mac
//
//  Created by Justin R. Miller on 9/13/13.
//  Copyright (c) 2013-2014 Mapbox. All rights reserved.
//

#import "MBXAppDelegate.h"

#import "MBXMapKit.h"

@interface MBXAppDelegate ()

@property (nonatomic) IBOutlet MBXMapView *mapView;

@end

@implementation MBXAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Mac project shows use via XIB
    //
    self.mapView.mapID = @"justin.map-pgygbwdm";
}

@end