//
//  ToneGenerator.h
//  ToneGenerator
//
//  Created by Kevin Lawson on 2013-01-07.
//  This is a wrapper for Matt Gallagher's fantastic tone generating code
//  available at http://www.cocoawithlove.com/2010/10/ios-tone-generator-introduction-to.html
//
//  Original notice included below:
//  ===============================
//
//  Created by Matt Gallagher on 2010/10/20.
//  Copyright 2010 Matt Gallagher. All rights reserved.
//
//  Permission is given to use this source code file, free of charge, in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.

#import <Foundation/Foundation.h>

@interface ToneGenerator : NSObject

@property (nonatomic) double frequency;
@property (nonatomic) double amplitude;
@property (nonatomic) double sampleRate;
@property (nonatomic) double theta;

@property (nonatomic, readonly) BOOL isPlaying;

// Note: start and stop may cause clicks.  Use startWithFadeInDuration and stopWithFadeOutDuration with short durations (say, 0.1) for a softer start/stop.

- (void)start;
- (void)startWithFadeInDuration:(NSTimeInterval)duration;
- (void)stop;
- (void)stopWithFadeOutDuration:(NSTimeInterval)duration;
- (void)playPattern:(NSArray *)pattern withRepeat:(BOOL)repeat;
- (void)cleanup;

@end

// TGPatternSegment
// Throw some of these in an NSArray and baby you got a pattern goin' http://www.youtube.com/watch?v=5lFZAyZPjV0
@interface TGPatternSegment : NSObject

@property (nonatomic) double frequency;
@property (nonatomic) NSTimeInterval duration;

@end