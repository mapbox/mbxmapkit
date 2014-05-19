//
//  MBXConstantsAndTypes.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

#ifndef MBXMapKit_MBXConstantsAndTypes_h
#define MBXMapKit_MBXConstantsAndTypes_h


#pragma mark - Constants for the MBXMapKit error domain

/** Error domain for MBXMapKit */
extern NSString *const MBXMapKitErrorDomain;
/** Received an HTTP status other than 200 */
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
/** An required key is missing from the metadata or markers JSON dictionary */
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
/** An offline map download was cancelled before completion */
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
/** An offline map database does not contain a requested resource */
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL;
/** There was an sqlite error while accessing an offline map database */
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
/** There is a network connectivity problem such as airplane mode */
extern NSInteger const MBXMapKitErrorCodeURLSessionConnectivity;


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
