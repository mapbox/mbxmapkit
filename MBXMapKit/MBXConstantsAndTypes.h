//
//  MBXConstantsAndTypes.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#ifndef MBXMapKit_MBXConstantsAndTypes_h
#define MBXMapKit_MBXConstantsAndTypes_h


#pragma mark - Constants for the MBXMapKit error domain

extern NSString *const MBXMapKitErrorDomain;
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL;
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
extern NSInteger const MBXMapKitErrorCodeURLSessionConnectivity;
extern NSInteger const MBXMapKitErrorCodeMBTilesDatabaseHasNoDataForPath;


#pragma mark - Image quality constants

/** Map tile image quality options. */
typedef NS_ENUM(NSUInteger, MBXRasterImageQuality) {
    /** Full image quality. */
    MBXRasterImageQualityFull = 0,
    /** 32 color indexed PNG. */
    MBXRasterImageQualityPNG32 = 1,
    /** 64 color indexed PNG. */
    MBXRasterImageQualityPNG64 = 2,
    /** 128 color indexed PNG. */
    MBXRasterImageQualityPNG128 = 3,
    /** 256 color indexed PNG. */
    MBXRasterImageQualityPNG256 = 4,
    /** 70% quality JPEG. */
    MBXRasterImageQualityJPEG70 = 5,
    /** 80% quality JPEG. */
    MBXRasterImageQualityJPEG80 = 6,
    /** 90% quality JPEG. */
    MBXRasterImageQualityJPEG90 = 7
};



#endif
