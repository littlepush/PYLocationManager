//
//  PYLocationManager.h
//  PYLocationManager
//
//  Created by Push Chen on 9/28/15.
//  Copyright © 2015 PushLab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PYCore.h"
#import <CoreLocation/CoreLocation.h>

#define kPYLocationEventUpdateLastLocation     0x0001

typedef NS_ENUM(NSInteger, PYMapType)
{
    PYMapTypeBaidu     = 1,
    PYMapTypeGaode     = 2,
    PYMapTypeAMap      = 2,
    PYMapTypeGoogleMap = 3
};

typedef void (^PYGetCoordinate)(CLLocationCoordinate2D coordinate);
typedef void (^PYGetLocation)(CLLocationCoordinate2D);


// The map item
@interface PYMapItem : NSObject

@property (nonatomic, assign)   PYMapType      type;
@property (nonatomic, copy)     NSString        *mapName;

@end

@interface PYLocationManager : PYActionDispatcher <PYService>

- (void)bindGpsDBPath:(NSString *)path;

/*! the accuracy to filter the GPS locate. default is 100 meter */
@property (nonatomic, assign)   double                      accuracy;

/*! last location point */
@property (nonatomic, readonly) CLLocationCoordinate2D      lastLocation;

- (void)getCurrentLocation:(PYGetLocation)location;

/*!
 @brief get coordinate via address string
 */
- (void)getCoordinateWithAddress:(NSString *)address complete:(PYGetCoordinate)complete;

// All support maps type
- (NSArray *)availableMaps;

// Get the scheme
- (NSString *)map:(PYMapType)map urlSchemeTo:(CLLocationCoordinate2D)dest withName:(NSString *)name;

@end

