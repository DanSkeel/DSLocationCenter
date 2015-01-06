//
//  DSLocationCenter.h
//
//  Created by Danila Shikulin on 6/12/12.
//

// This code is distributed under the terms and conditions of the MIT license.

// Copyright (c) 2011 Danila Shikulin
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <CoreLocation/CoreLocation.h>

typedef NS_ENUM(NSInteger, DSLRFinishStatus) {
    DSLRFinishStatusReachedAccuracy,
    DSLRFinishStatusCanceled,
    DSLRFinishStatusTimeOut,
    DSLRFinishStatusError,
    DSLRFinishStatusNotProperlyAuthorized
};

typedef void(^newBestLocationBlock)(CLLocation *newBestLocation, BOOL *finish);
typedef void(^finishBlock)(DSLRFinishStatus finishStatus, NSError *error);

typedef void(^revGeoCodingBlock)(NSDictionary *addressDictionary);
typedef void(^geoCodingBlock)(CLLocation *location);

@interface DSLocationRequest : NSObject
/**
 *  You can receive duplicates of CLLocationManagerDelegate method calls during the work of center.
 *  Any returned values from your methods are ignored.
 */
@property (weak, nonatomic) NSObject<CLLocationManagerDelegate> *forwardDelegate;

/** how old location candidate can be*/
@property (nonatomic) NSTimeInterval timeRelevance;

/** Accuracy to be reached. If reached, finish. */
@property (nonatomic) CLLocationAccuracy desiredAccuracy;

/** Lower bound of accuracy filter. Locations that precise enough for this bound will be sent
 * but positioning process will continue until desired accuracy reached or timeout.*/
@property (nonatomic) CLLocationAccuracy minAccuracy;

/** Maximum time period of positioning process */
@property (nonatomic) NSTimeInterval timeOut;

+ (NSString *)stringForFinishStatus:(DSLRFinishStatus)status;

/** Simply call init */
+ (id)request;

/** Block that will be called every time the location candidate is passing all specified constraints */
- (void)setNewBestLocationBlock:(newBestLocationBlock)newBestLocationBlock;

/** Block will be called when positioning process */
- (void)setFinishBlock:(finishBlock)finishBlock;

/** Call to cancel positioning process*/
- (void)cancel;
@end

/** Class that provides simplified interface for CLLocationManger
 *  @warning you must provide NSLocationWhenInUseUsageDescription key in info.plist for iOS 8
 */
@interface DSLocationCenter : NSObject
/** Returnes location center singleton */
+ (id)sharedLocationCenter;

/** Add process to "queue" of positioning porcess */
- (void)processRequest:(DSLocationRequest *)request;

/** returnes address dictionary for location.
 *  @see addressDictionary property in CLPlacemark */
+ (void)addressDictForLocation:(CLLocation *)aLocation withCompletiongBlock:(revGeoCodingBlock)completiongBlock;

/** Returnes localized address for addressDictionary
 *  @see addressDictionary property in CLPlacemark */
+ (NSString *)fullAddressFromDictionary:(NSDictionary *)addressDictionary;

@end
