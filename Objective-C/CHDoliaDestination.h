//
//  CHDoliaDestination.h
//  Dolia
//
//  Created by Sidney San Martín on 5/7/14.
//  Copyright (c) 2014 Coordinated Hackers. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHStreamInterface.h"
#import "CHDoliaOffer.h"

@interface CHDoliaDestination : NSObject

@property (retain) NSNetService *service;

- (id)initWithService:(NSNetService*)service;
- (NSString *)name;
- (void)sendOffer:(CHDoliaOffer *)offer;

@end