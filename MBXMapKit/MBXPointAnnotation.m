//
//  MBXPointAnnotation.m
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#import "MBXPointAnnotation.h"

@implementation MBXPointAnnotation

@synthesize coordinate = _coordinate;

- (CLLocationCoordinate2D)coordinate
{
    return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate
{
    [self willChangeValueForKey:@"coordinate"];
    _coordinate = coordinate;
    [self didChangeValueForKey:@"coordinate"];
}

@end
