//
//  MBXStandardDelegate.h
//  MBXMapKit
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>
#import "MBXSimplestyle.h"
#import "MBXRasterTileOverlay.h"

@interface MBXStandardDelegate : NSObject <MKMapViewDelegate, MBXRasterTileOverlayDelegate, MBXSimplestyleDelegate>

@property (weak,nonatomic) MKMapView *mapView;

@end
