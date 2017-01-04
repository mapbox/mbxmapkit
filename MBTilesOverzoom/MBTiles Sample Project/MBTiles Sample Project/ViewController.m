//
//  ViewController.m
//  MBTiles Sample Project
//
//  MBXMapKit Copyright (c) 2013-2015 Mapbox. All rights reserved.
//

#import "ViewController.h"
#import "MBXMBTilesOverlay.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mapView.delegate = self;
    
    MBXMBTilesOverlay *mbtiles;
    NSString *mbtilesPath;
    mbtilesPath = [[NSBundle mainBundle] pathForResource:@"USAMapZoom0to6" ofType:@"mbtiles"];
    mbtiles = [[MBXMBTilesOverlay alloc] initWithMBTilesPath:mbtilesPath];
    NSLog(@"metadata max zoom: %d", mbtiles.mbtilesMaxZoom);
    NSLog(@"metadata attribution: %@", mbtiles.attribution);
    
    [self.mapView addOverlay:mbtiles];
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay
{
    if([overlay isKindOfClass:[MKTileOverlay class]]) {
        MKTileOverlayRenderer *r = [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
        return r;
    }
    
    return nil;
}

@end
