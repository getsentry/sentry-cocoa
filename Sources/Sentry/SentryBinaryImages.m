//
//  SentryBinaryImages.m
//  Sentry
//
//  Created by Daniel Griesser on 06.04.20.
//  Copyright © 2020 Sentry. All rights reserved.
//

#import "SentryBinaryImages.h"
#import "SentryDebugMeta.h"

@implementation SentryBinaryImages

// TODO: copy sentrycrashdl_getBinaryImage here and make it work

+ (NSArray *)getDebugMeta {
    // TODO implement
//    NSMutableArray<SentryDebugMeta *> *result = [NSMutableArray new];
//    for (NSDictionary *sourceImage in self.report[@"binary_images"]) {
//        SentryDebugMeta *debugMeta = [[SentryDebugMeta alloc] init];
//        debugMeta.uuid = sourceImage[@"uuid"];
//        debugMeta.type = @"apple";
//        debugMeta.imageAddress = hexAddress(sourceImage[@"image_addr"]);
//        debugMeta.imageSize = sourceImage[@"image_size"];
//        debugMeta.name = sourceImage[@"name"];
//        [result addObject:debugMeta];
//    }
//    return result;
    return @[]; // Returns an array SentryDebugMeta containing all binary images
}

@end
