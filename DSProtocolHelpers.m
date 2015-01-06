//
//  DSProtocolHelpers.m
//
//  Created by Danila Shikulin on 11/8/13.
//  Copyright (c) 2013 Shikulin Danila
//

#import <objc/runtime.h>
#import <stdlib.h>

#import "DSProtocolHelpers.h"

#pragma mark - Selector conforms to protocol

BOOL DSSelectorIsInListOfProtocolMethodsWithProps(SEL selector, Protocol *protocol, BOOL isRequiredMethod, BOOL isInstanceMethod) {
    unsigned int count;
    struct objc_method_description *methods;
    methods = protocol_copyMethodDescriptionList(protocol, isRequiredMethod, isInstanceMethod, &count);
    for (int i = 0; i < count; ++i) {
        if (methods[i].name == selector) return YES;
    }
    free(methods);
    return NO;
}

BOOL DSSelectorConformsToProtocol(SEL selector, Protocol *protocol) {
    BOOL(^isAmongMethodsWithProps)(BOOL, BOOL) = ^(BOOL isRequiredMethod, BOOL isInstanceMethod) {
        return DSSelectorIsInListOfProtocolMethodsWithProps(selector, protocol, isRequiredMethod, isInstanceMethod);
    };
    if (isAmongMethodsWithProps(YES, YES)) return YES;
    if (isAmongMethodsWithProps(YES, NO)) return YES;
    if (isAmongMethodsWithProps(NO, YES)) return YES;
    if (isAmongMethodsWithProps(NO, NO)) return YES;
    return NO;
}
