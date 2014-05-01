//
//  MBXPointAnnotation.h
//  MBXMapKit
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MBXPointAnnotation : MKShape

#if TARGET_OS_IPHONE
@property (nonatomic) UIImage *image;
#else
@property (nonatomic) NSImage *image;
#endif

@end
