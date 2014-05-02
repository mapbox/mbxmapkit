//
//  MBXViewController.h
//  MBXMapKit iOS Demo v030
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "MBXRasterTileOverlay.h"
#import "MBXOfflineMapDownloader.h"

@interface MBXViewController : UIViewController <UIActionSheetDelegate, MKMapViewDelegate, MBXRasterTileOverlayDelegate, MBXOfflineMapDownloaderDelegate, UIAlertViewDelegate>

@end
