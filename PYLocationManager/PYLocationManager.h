//
//  PYLocationManager.h
//  PYLocationManager
//
//  Created by Push Chen on 9/28/15.
//  Copyright © 2015 PushLab. All rights reserved.
//

/*
 LGPL V3 Lisence
 This file is part of cleandns.
 
 PYCore is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 PYData is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with cleandns.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 LISENCE FOR IPY
 COPYRIGHT (c) 2013, Push Chen.
 ALL RIGHTS RESERVED.
 
 REDISTRIBUTION AND USE IN SOURCE AND BINARY
 FORMS, WITH OR WITHOUT MODIFICATION, ARE
 PERMITTED PROVIDED THAT THE FOLLOWING CONDITIONS
 ARE MET:
 
 YOU USE IT, AND YOU JUST USE IT!.
 WHY NOT USE THIS LIBRARY IN YOUR CODE TO MAKE
 THE DEVELOPMENT HAPPIER!
 ENJOY YOUR LIFE AND BE FAR AWAY FROM BUGS.
 */

#import <Foundation/Foundation.h>
#import "PYCore.h"
#import <CoreLocation/CoreLocation.h>

#define kPYLocationEventUpdateLastLocation      0x0001
#define kPYLocationEventFailedUpdating          0x0002

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

/*!
 The location manager
 */
@property (nonatomic, readonly) CLLocationManager           *locationManager;

/*!
 If the user denied the location in settings
 */
@property (nonatomic, readonly) BOOL                        isUserDeniedLocation;

/*! The location authorization status, default is Always */
@property (nonatomic, assign)   CLAuthorizationStatus       authorizationStatus;

- (void)bindGpsDBPath:(NSString *)path;

/*! if auto stop the server when get current location, default is NO */
@property (nonatomic, assign)   BOOL                        autoStop;

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

// @littlepush
// littlepush@gmail.com
// PYLab
