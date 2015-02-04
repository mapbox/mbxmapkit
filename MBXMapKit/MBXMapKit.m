//
//  MBXMapKit.m
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

#import "MBXMapKit.h"

NSString *const MBXMapKitVersion = @"0.7.0";

#pragma mark - Add support to MKMapView for using Mapbox-style center/zoom to configure the visible region

@implementation MKMapView (MBXMapView)

- (void)mbx_setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate zoomLevel:(NSUInteger)zoomLevel animated:(BOOL)animated
{
    zoomLevel = zoomLevel > 20 ? 20 : zoomLevel;

    MKCoordinateRegion region = MKCoordinateRegionMake(centerCoordinate, MKCoordinateSpanMake(0, 360 / (pow(2, zoomLevel) * (self.frame.size.width / 256))));
    [self setRegion:region animated:animated];
}

- (CGFloat)mbx_zoomLevel
{
    CGFloat zoomLevel = self.region.span.longitudeDelta;
    zoomLevel /= 360;
    zoomLevel /= (self.frame.size.width / 256);
    zoomLevel = log2f(zoomLevel);
    zoomLevel = fabs(zoomLevel);

    return zoomLevel;
}

@end

#pragma mark - Constants for the MBXMapKit error domain

NSString *const MBXMapKitErrorDomain = @"MBXMapKitErrorDomain";
NSInteger const MBXMapKitErrorCodeHTTPStatus = -1;
NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys = -2;
NSInteger const MBXMapKitErrorCodeDownloadingCanceled = -3;
NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL = -4;
NSInteger const MBXMapKitErrorCodeOfflineMapSqlite = -5;
NSInteger const MBXMapKitErrorCodeURLSessionConnectivity = -6;

#pragma mark - Global configuration

@interface MBXMapKit ()

@property (nonatomic) NSString *accessToken;
@property (nonatomic) NSString *userAgent;

@end

#pragma mark -

@implementation MBXMapKit

+ (instancetype)sharedInstance
{
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^(void)
    {
        _sharedInstance = [[self alloc] init];
    });

    return _sharedInstance;
}

+ (void)setAccessToken:(NSString *)accessToken
{
    [[MBXMapKit sharedInstance] setAccessToken:accessToken];
}

+ (NSString *)accessToken
{
    NSAssert([[MBXMapKit sharedInstance] accessToken], @"An access token is required in order to use the Mapbox API. Obtain a token on your Mapbox account page at https://www.mapbox.com/account/apps/.");

    return [[MBXMapKit sharedInstance] accessToken];
}

+ (void)setUserAgent:(NSString *)userAgent
{
    [[MBXMapKit sharedInstance] setUserAgent:userAgent];
}

+ (NSString *)userAgent
{
    NSString *userAgent = [[MBXMapKit sharedInstance] userAgent];

    if ( ! userAgent)
    {
#if TARGET_OS_IPHONE
        userAgent = [NSString stringWithFormat:@"MBXMapKit %@ (%@/%@)", MBXMapKitVersion, [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion]];
#else
        userAgent = [NSString stringWithFormat:@"MBXMapKit %@ (OS X/%@)", MBXMapKitVersion, [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif

        [[MBXMapKit sharedInstance] setUserAgent:userAgent];
    }

    return userAgent;
}

@end

#pragma mark - Helpers for creating verbose errors

@implementation NSError (MBXError)

+ (NSError *)mbx_errorWithCode:(NSInteger)code reason:(NSString *)reason description:(NSString *)description
{
    // Return an error in the MBXMapKit error domain with the specified reason and description
    //
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey        : NSLocalizedString(description, nil),
                                NSLocalizedFailureReasonErrorKey : NSLocalizedString(reason, nil) };

    return [NSError errorWithDomain:MBXMapKitErrorDomain code:code userInfo:userInfo];
}


+ (NSError *)mbx_errorCannotOpenOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError
{
    return [NSError mbx_errorWithCode:MBXMapKitErrorCodeOfflineMapSqlite reason:[NSString stringWithFormat:@"Unable to open database %@: %@", path, [NSString stringWithUTF8String:sqliteError]] description:@"Failed to open the sqlite offline map database file"];
}

+ (NSError *)mbx_errorQueryFailedForOfflineMapDatabase:(NSString *)path sqliteError:(const char *)sqliteError
{
    return [NSError mbx_errorWithCode:MBXMapKitErrorCodeOfflineMapSqlite reason:[NSString stringWithFormat:@"There was an sqlite error while executing a query on database %@: %@", path, [NSString stringWithUTF8String:sqliteError]] description:@"Failed to execute query"];
}

@end
