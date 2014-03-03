//
//  MBXxViewController.m
//  MBXMapKit iOS Demo v030
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXxViewController.h"
#import "MBXRasterTileOverlay.h"

@interface MBXxViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;

@end

@implementation MBXxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.mapID = @"examples.map-pgygbwdm";
    [_rasterOverlay addObserver:self forKeyPath:@"center" options:NSKeyValueObservingOptionNew context:nil];
    [_rasterOverlay addObserver:self forKeyPath:@"centerZoom" options:NSKeyValueObservingOptionNew context:nil];
    [_mapView addOverlay:_rasterOverlay];
    _mapView.delegate = self;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MBXRasterTileOverlay class]])
    {
        MKTileOverlayRenderer *renderer = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return renderer;
    }
    return nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([@"center" isEqualToString:keyPath])
    {
        [_mapView setCenterCoordinate:_rasterOverlay.center animated:NO];
    }
    else if([@"centerZoom" isEqualToString:keyPath])
    {
        [_mapView setRegion:MKCoordinateRegionMake(_rasterOverlay.center, MKCoordinateSpanMake(0, 360 / pow(2, _rasterOverlay.centerZoom) * _mapView.frame.size.width / 256)) animated:NO];
    }
}


@end
