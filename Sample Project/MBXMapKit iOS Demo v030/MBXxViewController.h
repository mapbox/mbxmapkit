//
//  MBXxViewController.h
//  MBXMapKit iOS Demo v030
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "MBXSimplestyle.h"
#import "MBXRasterTileOverlay.h"

@interface MBXxViewController : UIViewController <UIActionSheetDelegate, MKMapViewDelegate, MBXRasterTileOverlayDelegate, MBXSimplestyleDelegate>

@end
