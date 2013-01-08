//
//  ToneGenerator.h
//  ToneGenerator
//
//  Created by user on 1/7/13.
//
//

#import <Foundation/Foundation.h>

@interface ToneGenerator : NSObject

@property (nonatomic) double frequency;

- (void)play;
- (void)stop;

@end
