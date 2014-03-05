//
//  MBXxViewController.m
//  MBXMapKit iOS Demo v030
//
//  Created by Will Snook on 3/2/14.
//  Copyright (c) 2014 MapBox. All rights reserved.
//

#import "MBXxViewController.h"
#import "MBXRasterTileOverlay.h"
#import "MBXCacheManager.h"

@interface MBXxViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@property (nonatomic) MBXRasterTileOverlay *rasterOverlay;

@property (nonatomic) UIActionSheet *actionSheet;

@end

@implementation MBXxViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    //[[MBXCacheManager sharedCacheManager] invalidateMapID:@"examples.map-pgygbwdm"];

    _rasterOverlay = [[MBXRasterTileOverlay alloc] init];
    _rasterOverlay.mapID = @"examples.map-pgygbwdm";
    [_rasterOverlay addObserver:self forKeyPath:@"tileJSONDictionary" options:NSKeyValueObservingOptionNew context:nil];
    [_mapView addOverlay:_rasterOverlay];
    _mapView.delegate = self;
}

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)fullyRendered
{
    [[MBXCacheManager sharedCacheManager] sweepCache];
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
    if([@"tileJSONDictionary" isEqualToString:keyPath] && [object isKindOfClass:[MBXRasterTileOverlay class]])
    {
        CLLocationCoordinate2D center = [(MBXRasterTileOverlay *)object center];
        NSInteger centerZoom = [(MBXRasterTileOverlay *)object centerZoom];
        MKCoordinateRegion region = MKCoordinateRegionMake(center, MKCoordinateSpanMake(0, 360 / pow(2, centerZoom) * _mapView.frame.size.width / 256));
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            [_mapView setRegion:region animated:NO];
        });
    }
}

- (UIActionSheet *)universalActionSheet
{
    return [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"cancel" destructiveButtonTitle:nil otherButtonTitles:@"OSM world map",@"OSM over Apple satellite",@"Terrain under Apple labels",@"Tilemill bounded region",@"Tilemill region over Apple",@"Tilemill transparent over Apple", nil];
}

- (IBAction)iPadInfoButtonAction:(id)sender {
    if(_actionSheet.visible) {
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:YES];
        _actionSheet = nil;
    } else {
        _actionSheet = [self universalActionSheet];
        [_actionSheet showFromRect:((UIButton *)sender).frame inView:self.view animated:YES];
    }
}

- (IBAction)iPhoneInfoButtonAction:(id)sender {
    if(_actionSheet.visible) {
        [_actionSheet dismissWithClickedButtonIndex:_actionSheet.cancelButtonIndex animated:YES];
        _actionSheet = nil;
    } else {
        _actionSheet = [self universalActionSheet];
        [_actionSheet showFromRect:((UIButton *)sender).frame inView:self.view animated:YES];
    }
}

- (void)resetMapViewAndRasterOverlayDefaults
{
    _mapView.mapType = MKMapTypeStandard;
    [_mapView removeOverlays:_mapView.overlays];
    _mapView.scrollEnabled = YES;
    _mapView.zoomEnabled = YES;
    _rasterOverlay.canReplaceMapContent = YES;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch(buttonIndex) {
        case 0:
            // OSM world map
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay.mapID = @"examples.map-pgygbwdm";
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 1:
            // OSM over Apple satellite
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.mapType = MKMapTypeSatellite;
            _rasterOverlay.canReplaceMapContent = NO;
            _rasterOverlay.mapID = @"justin.map-9tlo4knw";
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 2:
            // Terrain under Apple labels
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay.mapID = @"justin.map-mf07hryq";
            [_mapView insertOverlay:_rasterOverlay atIndex:0 level:MKOverlayLevelAboveRoads];
            break;
        case 3:
            // Tilemill bounded region (scroll & zoom limited to programmatic control only)
            [self resetMapViewAndRasterOverlayDefaults];
            _mapView.scrollEnabled = NO;
            _mapView.zoomEnabled = NO;
            _rasterOverlay.mapID = @"justin.NACIS2012";
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 4:
            // Tilemill region over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay.canReplaceMapContent = NO;
            _rasterOverlay.mapID = @"justin.clp-2011-11-03-1200";
            [_mapView addOverlay:_rasterOverlay];
            break;
        case 5:
            // Tilemill transparent over Apple
            [self resetMapViewAndRasterOverlayDefaults];
            _rasterOverlay.canReplaceMapContent = NO;
            _rasterOverlay.mapID = @"justin.pdx_meters";
            [_mapView addOverlay:_rasterOverlay];
            break;
    }
}

@end
