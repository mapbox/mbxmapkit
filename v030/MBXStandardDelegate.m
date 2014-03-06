//
//  MBXStandardDelegate.m
//  MBXMapKit
//
//  Created by Will Snook on 3/6/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXStandardDelegate.h"

@implementation MBXStandardDelegate

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
    // Schedule cache sweeps to occur each time a batch of tiles finishes rendering
    //
    [[MBXCacheManager sharedCacheManager] sweepCache];
}


- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    // This is boilerplate code to connect tile overlay layers with suitable renderers
    //
    if ([overlay isKindOfClass:[MBXRasterTileOverlay class]])
    {
        MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return renderer;
    }
    return nil;
}


- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    // This is boilerplate code to connect annotations with suitable views
    //
    if ([annotation isKindOfClass:[MBXPointAnnotation class]])
    {
        static NSString *MBXSimpleStyleReuseIdentifier = @"MBXSimpleStyleReuseIdentifier";
        MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:MBXSimpleStyleReuseIdentifier];
        if (!view)
        {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:MBXSimpleStyleReuseIdentifier];
        }
        view.image = ((MBXPointAnnotation *)annotation).image;
        view.canShowCallout = YES;
        return view;
    }
    return nil;
}


- (void)didLoadTileJSONForTileOverlay:(MBXRasterTileOverlay *)rasterOverlay
{
    // This required delegate callback is for centering the map once the TileJSON has been loaded
    //
    if(_mapView) {
        MKCoordinateRegion region = MKCoordinateRegionMake(rasterOverlay.center, MKCoordinateSpanMake(0, 360 / pow(2, rasterOverlay.centerZoom) * _mapView.frame.size.width / 256));
        [_mapView setRegion:region animated:NO];
    }
    else
    {
        NSLog(@"Warning: MBXStandardDelegate's mapView property is not set (didLoadTileJSONForTileOverlay:)");
    }
}


- (void)didParseSimplestylePoint:(MBXPointAnnotation *)pointAnnotation
{
    // This required delegate callback is for adding points to an MKMapView when they are successfully parsed from the simplestyle
    //
    if(_mapView) {
        [_mapView addAnnotation:pointAnnotation];
    }
    else
    {
        NSLog(@"Warning: MBXStandardDelegate's mapView property is not set (didParseSimplestylePoint:)");
    }
}


- (void)didFailToLoadTileJSONForMapID:(NSString *)mapID withError:(NSError *)error
{
    // This optional delegate callback is for handling situations when something goes wrong with the TileJSON
    //
    NSLog(@"Delegate received notification of TileJSON loading failure - (%@)",error?error:@"");
}


- (void)didFailToLoadSimplestyleForMapID:(NSString *)mapID withError:(NSError *)error
{
    // This optional delegate callback is for handling situations when something goes wrong with the simplestyle
    //
    NSLog(@"Delegate received notification of Simplestyle loading failure - (%@)",error?error:@"");
}

@end
