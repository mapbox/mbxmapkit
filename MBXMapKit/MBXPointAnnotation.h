//
//  MBXPointAnnotation.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface MBXPointAnnotation : MKShape

#if TARGET_OS_IPHONE
@property (nonatomic) UIImage *image;
#else
@property (nonatomic) NSImage *image;
#endif

@end
