//
//  DSProtocolHelpers.m
//
//  Created by Danila Shikulin on 11/8/13.
//  Copyright (c) 2013 Shikulin Danila
//

#import <Foundation/Foundation.h>

BOOL DSSelectorIsInListOfProtocolMethodsWithProps(SEL selector, Protocol *protocol, BOOL isRequiredMethod, BOOL isInstanceMethod);
BOOL DSSelectorConformsToProtocol(SEL selector, Protocol *protocol);
