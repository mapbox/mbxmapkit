//
//  MBXzAppDelegate.h
//  MBXMapKit Mac Demo v030
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <MapKit/MapKit.h>
#import "MBXSimplestyle.h"
#import "MBXRasterTileOverlay.h"

@interface MBXzAppDelegate : NSObject <NSApplicationDelegate, MKMapViewDelegate, MBXRasterTileOverlayDelegate, MBXSimplestyleDelegate>

@property (assign) IBOutlet NSWindow *window;

@end
