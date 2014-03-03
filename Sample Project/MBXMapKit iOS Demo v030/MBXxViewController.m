//
//  MBXxViewController.m
//  MBXMapKit iOS Demo v030
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXxViewController.h"
#import "MBXRasterTileOverlay.h"
#import "MBXTileOverlayRenderer.h"

@interface MBXxViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation MBXxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    MBXRasterTileOverlay *rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    rasterOverlay.mapID = @"examples.map-pgygbwdm";
    [_mapView addOverlay:rasterOverlay];
    _mapView.delegate = self;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MBXRasterTileOverlay class]])
    {
        MBXTileOverlayRenderer *renderer = [[MBXTileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return renderer;
    }
    return nil;
}


@end
