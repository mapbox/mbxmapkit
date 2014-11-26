//
//  MBXPointAnnotation.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "TargetConditionals.h"

#if TARGET_OS_IPHONE
@import UIKit;
#else
@import AppKit;
#endif

@import MapKit;

/** The `MBXPointAnnotation` class defines a concrete annotation object located at a specified point and with a custom image. You can use this class, rather than define your own, in situations where all you want to do is associate a point on the map with a title. */
@interface MBXPointAnnotation : MKShape

/** @name Accessing the Annotation’s Location */

/** The coordinate point of the annotation, specified as a latitude and longitude. */
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

/** @name Getting and Setting Attributes */

/** The image to show upon display of the corresponding auto-created `MKAnnotationView`. */
#if TARGET_OS_IPHONE
@property (nonatomic) UIImage *image;
#else
@property (nonatomic) NSImage *image;
#endif

@end
