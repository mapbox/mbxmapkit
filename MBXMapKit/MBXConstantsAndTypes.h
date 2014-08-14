//
//  MBXConstantsAndTypes.h
//  MBXMapKit
//
//  Copyright (c) 2014 Mapbox. All rights reserved.
//

@import Foundation;

#ifndef MBXMapKit_MBXConstantsAndTypes_h
#define MBXMapKit_MBXConstantsAndTypes_h

#pragma mark - Library version

extern NSString *const MBXMapKitVersion;

#pragma mark - Constants for the MBXMapKit error domain

/** The MBXMapKit error domain. */
extern NSString *const MBXMapKitErrorDomain;
/** An HTTP status other than 200 was received. */
extern NSInteger const MBXMapKitErrorCodeHTTPStatus;
/** A required key is missing from the metadata or markers JSON dictionary. */
extern NSInteger const MBXMapKitErrorCodeDictionaryMissingKeys;
/** An offline map download was cancelled before completion. */
extern NSInteger const MBXMapKitErrorCodeDownloadingCanceled;
/** An offline map database does not contain a requested resource. */
extern NSInteger const MBXMapKitErrorCodeOfflineMapHasNoDataForURL;
/** There was a SQLite error while accessing an offline map database. */
extern NSInteger const MBXMapKitErrorCodeOfflineMapSqlite;
/** There is a network connectivity problem such as airplane mode. */
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
