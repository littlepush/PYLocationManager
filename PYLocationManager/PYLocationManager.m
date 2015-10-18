//
//  PYLocationManager.m
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

#import "PYLocationManager.h"
#import "PYData.h"
#import <UIKit/UIKit.h>

static PYLocationManager *_glocMgr = nil;

@implementation PYMapItem

- (id)initWithType:(PYMapType)type name:(NSString *)name
{
    self = [super init];
    if ( self ) {
        self.type = type;
        self.mapName = [name copy];
    }
    return self;
}
@end

@interface PYLocationManager () <CLLocationManagerDelegate>
{
    CLLocationManager                   *_locationManager;
    BOOL                                _authStatusPendingStarting;
    sqlite3                             *_dbForGpsCache;
    PYSqlStatement                      *_gpsQueryState;
    CLLocationCoordinate2D              _lastLocation;
    
    NSMutableArray                      *_pendingBlocks;
    NSMutableArray                      *_availableMaps;
    
    CLGeocoder                          *_geocoder;
}

@end

@implementation PYLocationManager

@synthesize lastLocation = _lastLocation;

@synthesize locationManager = _locationManager;

// Singleton
- (id)init
{
    self = [super init];
    if ( self ) {
        // Default YueDong Office GPS
        _lastLocation = CLLocationCoordinate2DMake(31.236315 - 0.0065, 121.525282 - 0.006);
        self.accuracy = 100.f;
        self.autoStop = NO;
        self.authorizationStatus = kCLAuthorizationStatusAuthorizedAlways;
        
        _pendingBlocks = [NSMutableArray array];
        
        _availableMaps = [NSMutableArray array];
        if ( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"baidumap://"]] ) {
            [_availableMaps addObject:[[PYMapItem alloc] initWithType:PYMapTypeBaidu name:@"百度地图"]];
        }
        if ( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"iosamap://"]] ) {
            [_availableMaps addObject:[[PYMapItem alloc] initWithType:PYMapTypeAMap name:@"高德地图"]];
        }
        if ( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps://"]] ) {
            [_availableMaps addObject:[[PYMapItem alloc] initWithType:PYMapTypeGoogleMap name:@"Google地图"]];
        }
    }
    return self;
}
+ (instancetype)shared
{
    PYSingletonLock
    if ( _glocMgr == nil ) {
        _glocMgr = [PYLocationManager object];
    }
    return _glocMgr;
    PYSingletonUnLock
}

PYSingletonAllocWithZone(_glocMgr)
PYSingletonDefaultImplementation

@dynamic isUserDeniedLocation;
- (BOOL)isUserDeniedLocation
{
    return ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied);
}

// PYServices

- (BOOL)startService
{
    CLAuthorizationStatus _as = [CLLocationManager authorizationStatus];
    if ( _as == kCLAuthorizationStatusDenied ) return NO;
    
    if ( _dbForGpsCache == nil ) return NO;
    
    // Star to get current location
    if ( _locationManager != nil ) {
        [_locationManager stopUpdatingLocation];
        _locationManager = nil;
    }
    
    if ( [CLLocationManager locationServicesEnabled] == NO ) return NO;
    
    _locationManager = [CLLocationManager object];
    _locationManager.delegate = self;
    
    if ( _as < kCLAuthorizationStatusDenied ) { // Not Allowed
        
        _authStatusPendingStarting = YES;
        if ( self.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ) {
            [_locationManager requestAlwaysAuthorization];
        } else {
            [_locationManager requestWhenInUseAuthorization];
        }
    } else {
        
        _authStatusPendingStarting = NO;
        [_locationManager startUpdatingLocation];
    }
    return YES;
}

- (BOOL)stopService
{
    if ( _locationManager == nil ) return YES;
    [_locationManager stopUpdatingLocation];
    _locationManager = nil;
    _authStatusPendingStarting = NO;
    return YES;
}

- (BOOL)restartService
{
    [self stopService];
    return [self startService];
}

@dynamic isRunning;
- (BOOL)isRunning
{
    return _locationManager != nil;
}

// Initialize the GPS DB
- (void)bindGpsDBPath:(NSString *)dbPath
{
    if (sqlite3_open([dbPath UTF8String], &_dbForGpsCache) == SQLITE_OK) {
        char *_errorMsg = NULL;
        sqlite3_exec(_dbForGpsCache, "PRAGMA synchronous = OFF", NULL, NULL, &_errorMsg);
        if ( _errorMsg != NULL ) {
            ALog(@"Failed to set the sqlite to be async mode: %s", _errorMsg);
            return;
        }
        sqlite3_exec(_dbForGpsCache, "PRAGMA journal_mode = MEMORY", NULL, NULL, &_errorMsg);
        if ( _errorMsg != NULL ) {
            ALog(@"Failed to set the journal_mode to memory: %s", _errorMsg);
            return;
        }
        
        // Prepare sqlitement
        NSString *_queryString = @"SELECT offLat,offLog FROM gpsT WHERE lat=? and log=?";
        _gpsQueryState = [PYSqlStatement sqlStatementWithSQL:_queryString];
        if (sqlite3_prepare_v2(_dbForGpsCache, _queryString.UTF8String, -1,
                               &_gpsQueryState->sqlstmt, NULL) != SQLITE_OK) {
            ALog(@"Failed to initialize the select statement: %s", sqlite3_errmsg(_dbForGpsCache));
            return;
        }
    }
}

- (CLLocationCoordinate2D)gpsTransform:(CLLocationCoordinate2D)originGps
{
    if ( _dbForGpsCache == nil ) return originGps;
    PYSingletonLock
    int _tLat = (int)(originGps.latitude * 10), _tLog = (int)(originGps.longitude * 10);
    [_gpsQueryState resetBinding];
    [_gpsQueryState bindInOrderInt:_tLat];
    [_gpsQueryState bindInOrderInt:_tLog];
    int _offLat = 0, _offLog = 0;
    if (sqlite3_step(_gpsQueryState.statement) == SQLITE_ROW )
    {
        [_gpsQueryState prepareForReading];
        _offLat = [_gpsQueryState getInOrderInt];
        _offLog = [_gpsQueryState getInOrderInt];
    }
    
    CLLocationCoordinate2D _newLocation;
    _newLocation.latitude = originGps.latitude + _offLat * 0.0001;
    _newLocation.longitude = originGps.longitude + _offLog * 0.0001;
    return _newLocation;
    PYSingletonUnLock
}

// Location Manager Delegate
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    //PYLog(@"Loc Error: %@", error);
    [self invokeTargetWithEvent:kPYLocationEventFailedUpdating exInfo:error];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    // The user not allow us to get the gps
    if ( status > kCLAuthorizationStatusDenied && _authStatusPendingStarting ) {
        [manager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // just update info.
    CLLocation *_newLoc = [locations lastObject];
    // Skip indoor point.
    if ( _newLoc.horizontalAccuracy > self.accuracy ) return;
    _lastLocation = [self gpsTransform:_newLoc.coordinate];
    
    if ( self.autoStop ) {
        [self stopService];
    }
    
    // Tell the listener
    [self invokeTargetWithEvent:kPYLocationEventUpdateLastLocation];
    
    NSArray *_blockArray = nil;
    PYSingletonLock
    _blockArray = [_pendingBlocks copy];
    [_pendingBlocks removeAllObjects];
    PYSingletonUnLock
    
    for ( PYGetLocation locBlock in _blockArray) {
        locBlock( _lastLocation );
    }
}

- (void)getCurrentLocation:(PYGetLocation)location
{
    PYSingletonLock
    if ( location != nil ) {
        [_pendingBlocks addObject:location];
    }
    if ( [self isRunning] ) {
        return;
    } else {
        [self startService];
    }
    PYSingletonUnLock
}

- (void)getCoordinateWithAddress:(NSString *)address complete:(PYGetCoordinate)complete
{
    if ( _geocoder == nil ) {
        _geocoder = [CLGeocoder object];
    }
    [_geocoder geocodeAddressString:address completionHandler:^(NSArray *placemarks, NSError *error) {
        if ( error || [placemarks count] == 0 ) {
            if ( complete ) complete([PYLocationManager shared].lastLocation);
        } else {
            CLPlacemark *_pm = [placemarks safeObjectAtIndex:0];
            if ( complete ) complete(_pm.location.coordinate);
        }
    }];
}

- (NSArray *)availableMaps
{
    return [_availableMaps copy];
}

- (NSString *)map:(PYMapType)map urlSchemeTo:(CLLocationCoordinate2D)dest withName:(NSString *)name
{
    if ( map == PYMapTypeBaidu ) {
        return [NSString stringWithFormat:@"baidumap://map/direction?origin=latlng:%f,%f|name:我的位置&destination=latlng:%f,%f|name:%@&mode=transit&src=%@",
                self.lastLocation.latitude, self.lastLocation.longitude,
                dest.latitude, dest.longitude,
                name, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]];
    }
    if ( map == PYMapTypeAMap ) {
        return [NSString stringWithFormat:@"iosamap://navi?sourceApplication=%@&backScheme=applicationScheme&poiname=fangheng&poiid=BGVIS&lat=%f&lon=%f&dev=0&style=3",
                name, dest.latitude, dest.longitude];
    }
    if ( map == PYMapTypeGoogleMap ) {
        return [NSString stringWithFormat:@"comgooglemaps-x-callback://?saddr=&daddr=%f,%f&daddr=%f,%f&directionsmode=transit&x-success=yuedong_1_0://?resume=true&x-source=%@",
                dest.latitude, dest.longitude,
                self.lastLocation.latitude, self.lastLocation.longitude,
                name];
    }
    return @"";
}

@end

// @littlepush
// littlepush@gmail.com
// PYLab
