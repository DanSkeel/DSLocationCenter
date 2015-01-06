//
//  DSLocationCenter.m
//
//  Created by Danila Shikulin on 6/12/12.
//  Copyright (c) 2012 Danila Shikulin
//

#import <AddressBookUI/AddressBookUI.h>

#import "DSLocationCenter.h"

#import "DSProtocolHelpers.h"

#define DS_SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

#ifdef DS_LOCATION_CENTER_DEBUG_LOG
#       define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#       define DLog(...)
#endif


@protocol DSLocationRequestDelegate <NSObject>
- (void)requestFinished:(DSLocationRequest *)request;
@end

@interface DSLocationRequest ()
@property (weak, nonatomic) id<DSLocationRequestDelegate> delegate;
- (void)processingStarted;
- (void)newBestLocation:(CLLocation *)newBestLocation;
- (void)finishNotProperlyAuthorized;
- (void)finishWithError:(NSError *)error;
@end

@interface DSLocationCenter () <CLLocationManagerDelegate, DSLocationRequestDelegate>
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) CLLocation *bestLocationEffort;
@property (strong, nonatomic) NSArray *requests;
@end

#define UNSET_AUTH_STATUS -1

@implementation DSLocationCenter {
    CLAuthorizationStatus _statusBeforeAskingPermission;
}

+ (id) sharedLocationCenter {
    static dispatch_once_t pred = 0;
    __strong static id _sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (instancetype)init {
    if (self = [super init]) {
        _statusBeforeAskingPermission = UNSET_AUTH_STATUS;
    }
    return self;
}

- (NSArray *)requests {
    if (!_requests) {
        _requests = @[];
    }
    return _requests;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL aSelector = [invocation selector];
    
    // forward only CLLocationManagerDelegate methods.
    if (DSSelectorConformsToProtocol(aSelector, @protocol(CLLocationManagerDelegate))) {
        DLog(@"conforms!");
        [self.requests enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
            [invocation invokeWithTarget:request];
        }];
    }
    [super forwardInvocation:invocation];
}

- (void)processRequest:(DSLocationRequest *)request {
    NSAssert(request != nil, @"Can't process nil request");
    DLog(@"\n---------------\nNEW REQUEST\n---------------");
    DLog(@"===SETUP BEGIN");
    if ([self.requests containsObject:request]) {
        ALog(@"Warning, trying to process request while it is being processed");
        return;
    }
    self.requests = [self.requests arrayByAddingObject:request];
    DLog(@"%lu requests left", (unsigned long)self.requests.count);
    request.delegate = self;
    [request processingStarted];
        
    DLog(@"locManager = %@", self.locationManager);
    if (self.locationManager) {
        CLLocationManager *locManager = self.locationManager;
        if (locManager.desiredAccuracy > request.desiredAccuracy) {
            DLog(@"will change accurcay from %lg to %lg", locManager.desiredAccuracy, request.desiredAccuracy);
            locManager.desiredAccuracy = request.desiredAccuracy;
        }
        if (self.bestLocationEffort) {
            [request newBestLocation:self.bestLocationEffort];
        }
    } else {
        self.bestLocationEffort = nil;
        CLLocationManager *newLocManager = [[CLLocationManager alloc] init];
        newLocManager.delegate = self;
        newLocManager.desiredAccuracy = request.desiredAccuracy;
        self.locationManager = newLocManager;
        [self finishSetupLocationManager:newLocManager];
    }
    DLog(@"===SETUP END\n\n");
}

- (void)finishSetupLocationManager:(CLLocationManager *)manager {
    CLAuthorizationStatus status = CLLocationManager.authorizationStatus;
    switch (status) {
        case kCLAuthorizationStatusAuthorizedAlways:
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            DLog(@"startUpdatingLocation");
            [manager startUpdatingLocation];
            break;
        case kCLAuthorizationStatusNotDetermined:
            DLog(@"Ask permission");
            if (DS_SYSTEM_VERSION_LESS_THAN(@"8.0")) {
                [manager startUpdatingLocation];
            } else {
                _statusBeforeAskingPermission = kCLAuthorizationStatusNotDetermined;
                [manager requestWhenInUseAuthorization];  // for now requests doesn't have parameters that need `AlwaysAuthorization`
            }
            break;
        default:
            DLog(@"No permission, will stop center");
            for (DSLocationRequest *request in self.requests)
                [request finishNotProperlyAuthorized];
            [self stopCenter];
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    DLog(@"Status: %d", status);
    // forwarding messages to forwardDelegate
    [self.requests enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        if ([request respondsToSelector:@selector(locationManager:didChangeAuthorizationStatus:)])
            [request locationManager:manager didChangeAuthorizationStatus:status];
    }];
    
    // this is related to iOS 8. We need to start manager after askeing for permission.
    if (_statusBeforeAskingPermission == kCLAuthorizationStatusNotDetermined) {
        _statusBeforeAskingPermission = UNSET_AUTH_STATUS;
        [self finishSetupLocationManager:manager];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    // forwarding messages to forwardDelegate
    [self.requests enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        if ([request respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)])
            [request locationManager:manager didUpdateToLocation:newLocation fromLocation:oldLocation];
    }];

    DLog(@"new location: %@", newLocation);
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5.0)  {
        DLog(@"location is old: %g", locationAge);
        [self.requests makeObjectsPerformSelector:@selector(newBestLocation:) withObject:newLocation];
        return;
    }
    DLog(@"location is new enough");
    // test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) {
        DLog(@"Location is invalid, acc = %lg", newLocation.horizontalAccuracy);
        return;
    }
    DLog(@"location is accurate enough, acc = %lg", newLocation.horizontalAccuracy);
    // test the measurement to see if it is more accurate than the previous measurement
    if (self.bestLocationEffort == nil || self.bestLocationEffort.horizontalAccuracy > newLocation.horizontalAccuracy) {
        // store the location as the "best effort"
        DLog(@"new best effort!");
        self.bestLocationEffort = newLocation;
        [self.requests makeObjectsPerformSelector:@selector(newBestLocation:) withObject:newLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    // forwarding messages to forwardDelegate
    [self.requests enumerateObjectsUsingBlock:^(id request, NSUInteger idx, BOOL *stop) {
        if ([request respondsToSelector:@selector(locationManager:didFailWithError:)])
            [request locationManager:manager didFailWithError:error];
    }];
    
    if (error.code == kCLErrorDenied) {
        [self.requests makeObjectsPerformSelector:@selector(finishNotProperlyAuthorized)];
    } else if (error.code != kCLErrorLocationUnknown) {
        [self.requests makeObjectsPerformSelector:@selector(finishWithError:) withObject:error];
        ALog(@"Failed with error: %@", error.description);
    }
}

- (void)requestFinished:(DSLocationRequest *)request {
    DLog(@"called");
    NSMutableArray *mutRequests = self.requests.mutableCopy;
    [mutRequests removeObject:request];
    self.requests = mutRequests;
    if (self.requests.count == 0) [self stopCenter];
    DLog(@"%lu requests left", (unsigned long)self.requests.count);
}

- (void)stopCenter {
    DLog(@"called");
    [self.locationManager stopUpdatingLocation];
    self.locationManager.delegate = nil;
    self.locationManager = nil;
}

+ (void)addressDictForLocation:(CLLocation *)aLocation withCompletiongBlock:(revGeoCodingBlock)completiongBlock {
    static NSDictionary *cachedAddressDictionary;
    static CLLocation *cachedLocation;
    
    if ([aLocation isEqual:cachedLocation]) {
        completiongBlock(cachedAddressDictionary);
    }
    cachedLocation = aLocation;
    CLGeocoder *geocoder = [[CLGeocoder alloc] init];
    [geocoder reverseGeocodeLocation:aLocation completionHandler:
     ^(NSArray* placemarks, NSError* error){
         if ([placemarks count] > 0)
         {
             CLPlacemark *placemark = placemarks[0];
             cachedAddressDictionary = placemark.addressDictionary;
             completiongBlock(cachedAddressDictionary);
         } else {
             ALog(@"Geotaging error = %@", error);
         }
     }];
}

+ (NSString *)fullAddressFromDictionary:(NSDictionary *)addressDictionary {
    return ABCreateStringWithAddressDictionary(addressDictionary, NO);
}

@end

#define DEFAULT_TIME_RELEVANCE 5*60
#define DEFAULT_TIMEOUT 30

@interface DSLocationRequest ()
@property (strong, nonatomic) newBestLocationBlock newBestLocationBlock;
@property (strong, nonatomic) finishBlock finishBlock;
@property (weak, nonatomic) NSTimer *timer;
@end

@implementation DSLocationRequest

- (id)init {
    self = [super init];
    if (self) {
        _timeRelevance = DEFAULT_TIME_RELEVANCE;
        _minAccuracy = kCLLocationAccuracyThreeKilometers;
        _desiredAccuracy = kCLLocationAccuracyThreeKilometers;
        _timeOut = DEFAULT_TIMEOUT;
    }
    return self;
}

+ (id)request {
    return [[DSLocationRequest alloc] init];
}

- (void)setNewBestLocationBlock:(newBestLocationBlock)newBestLocationBlock {
    _newBestLocationBlock = [newBestLocationBlock copy];
}

- (void)setFinishBlock:(finishBlock)finishBlock {
    _finishBlock = [finishBlock copy];
}

- (void)processingStarted {
    NSAssert(self.newBestLocationBlock != nil, @"newBestLocationBlock not set!");
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.timeOut
                                                      target:self
                                                    selector:@selector(requestTimerFired:)
                                                    userInfo:nil
                                                     repeats:NO];
}

- (void)newBestLocation:(CLLocation *)newBestLocation {
    DLog(@"----Begin----");
    NSTimeInterval locationAge = -[newBestLocation.timestamp timeIntervalSinceNow];
    DLog(@"TimeRelevance(%lg), locAge(%lg)", self.timeRelevance, locationAge);
    if (locationAge > self.timeRelevance) {
        DLog(@"Not relevant by time");
    } else {        
        DLog(@"Relevant by time");
        
        CLLocationAccuracy bestLocAccuracy = newBestLocation.horizontalAccuracy;
        DLog(@"newAccuracy: %lg, minAccuracy: %lg", bestLocAccuracy, self.minAccuracy);
        if (bestLocAccuracy <= self.minAccuracy) {
            DLog(@"newBestLocationBlock");
            BOOL finish = NO;
            self.newBestLocationBlock(newBestLocation, &finish);
            DLog(@"newAccuracy: %lg, desiredAccuracy: %lg", bestLocAccuracy, self.desiredAccuracy);
            if (bestLocAccuracy <= self.desiredAccuracy) {
                [self finishWithStatus:DSLRFinishStatusReachedAccuracy error:nil];
            } else if (finish) {
                [self cancel];
            }
        }
    }
    DLog(@"----End----\n\n");
}

- (void)requestTimerFired:(NSTimer *)timer {
    DLog(@"called");
    [self finishWithStatus:DSLRFinishStatusTimeOut error:nil];
}

- (void)cancel {
    DLog(@"called");
    [self finishWithStatus:DSLRFinishStatusCanceled error:nil];
}

- (void)finishWithError:(NSError *)error {
    [self finishWithStatus:DSLRFinishStatusError error:error];
}

- (void)finishNotProperlyAuthorized {
    [self finishWithStatus:DSLRFinishStatusNotProperlyAuthorized error:nil];
}

- (void)finishWithStatus:(DSLRFinishStatus)finishStatus error:(NSError *)error {
    DLog(@"%@", [DSLocationRequest stringForFinishStatus:finishStatus]);
    [self.timer invalidate];
    [self.delegate requestFinished:self];
    self.delegate = nil;
    if (self.finishBlock) {
        self.finishBlock(finishStatus, error);
    }
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if (DSSelectorConformsToProtocol(aSelector, @protocol(CLLocationManagerDelegate))) {
        return [self.forwardDelegate respondsToSelector:aSelector];
    }
    return [super respondsToSelector:aSelector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    return [self.forwardDelegate methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL aSelector = [invocation selector];
    
    // forward only CLLocationManagerDelegate methods.
    if (DSSelectorConformsToProtocol(aSelector, @protocol(CLLocationManagerDelegate))) {
        [invocation invokeWithTarget:self.forwardDelegate];
    } else {
        [super forwardInvocation:invocation];
    }
}

+ (NSString *)stringForFinishStatus:(DSLRFinishStatus)status {
    switch (status) {
        case DSLRFinishStatusReachedAccuracy: return @"DSLRFinishStatusReachedAccuracy";
        case DSLRFinishStatusCanceled: return @"DSLRFinishStatusCanceled";
        case DSLRFinishStatusTimeOut: return @"DSLRFinishStatusTimeOut";
        case DSLRFinishStatusError: return @"DSLRFinishStatusError";
        case DSLRFinishStatusNotProperlyAuthorized: return @"DSLRFinishStatusNotProperlyAuthorized";
    }
}

@end
