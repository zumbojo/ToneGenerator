//
//  ToneGenerator.m
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

#import "ToneGenerator.h"
#import <AudioToolbox/AudioToolbox.h>

#define DEFAULT_AMPLITUDE 0.25

OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData);
void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState);

@interface ToneGenerator ()
{
    AudioComponentInstance toneUnit;
}

@property (nonatomic) NSTimer *fadeInTimer;
@property (nonatomic) NSTimer *fadeOutTimer;

@property (nonatomic) NSArray *pattern;
@property (nonatomic) NSUInteger patternIndex;
@property (nonatomic) BOOL patternShouldRepeat;
@property (nonatomic) NSTimer *patternTimer;

@end

@implementation ToneGenerator

- (id)init
{
    self = [super init]; // http://stackoverflow.com/a/12428407/103058
    if (self) {
        _frequency = 5000; // default frequency
        _amplitude = DEFAULT_AMPLITUDE;
        _sampleRate = 44100;
        
        OSStatus result = AudioSessionInitialize(NULL, NULL, ToneInterruptionListener, (__bridge void *)(self));
        if (result == kAudioSessionNoError)
        {
            UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
            AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
        }
        AudioSessionSetActive(true);
    }
    return self;
}

- (void)start {
    if (!toneUnit) {
        [self createToneUnit];
		
		// Stop changing parameters on the unit
		OSErr err = AudioUnitInitialize(toneUnit);
		NSAssert1(err == noErr, @"Error initializing unit: %hd", err);
		
		// Start playback
		err = AudioOutputUnitStart(toneUnit);
		NSAssert1(err == noErr, @"Error starting unit: %hd", err);
        
        _isPlaying = YES;
    }
}

- (void)startWithFadeInDuration:(NSTimeInterval)duration {
    if (!duration) {
        [self start];
        return;
    }
    
    self.amplitude = 0;
    [self start];
    
    const int steps = 50;
    NSTimeInterval interval = duration / steps;
    double amount = DEFAULT_AMPLITUDE / steps; // amount of amplitude increase per step
    
    self.fadeInTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(increaseAmplitude:) userInfo:[NSNumber numberWithDouble:amount] repeats:YES];
}

- (void)increaseAmplitude:(NSTimer *)timer {
    self.amplitude += [(NSNumber *)[timer userInfo] doubleValue];
    if (self.amplitude >= DEFAULT_AMPLITUDE) {
        [self.fadeInTimer invalidate];
    }
}

- (void)stop {
    if (self.patternTimer) {
        [self.patternTimer invalidate];
    }
    
	if (toneUnit)
	{
		AudioOutputUnitStop(toneUnit);
		AudioUnitUninitialize(toneUnit);
		AudioComponentInstanceDispose(toneUnit);
		toneUnit = nil;
        _amplitude = DEFAULT_AMPLITUDE;
        
        _isPlaying = NO;
	}
}

- (void)stopWithFadeOutDuration:(NSTimeInterval)duration {
    if (!duration) {
        [self stop];
        return;
    }
    
    const int steps = 50;
    NSTimeInterval interval = duration / steps;
    double amount = self.amplitude / steps; // amount of amplitude decrease per step
    
    self.fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(reduceAmplitude:) userInfo:[NSNumber numberWithDouble:amount] repeats:YES];
}

- (void)reduceAmplitude:(NSTimer *)timer {
    self.amplitude -= [(NSNumber *)[timer userInfo] doubleValue];
    if (self.amplitude <= 0) {
        [self.fadeOutTimer invalidate];
        [self stop];
    }
}

- (void)playPattern:(NSArray *)pattern withRepeat:(BOOL)repeat {
    self.pattern = pattern;
    self.patternIndex = 0;
    self.patternShouldRepeat = repeat;
    [self playPatternSegment];
}

- (void)playPatternSegment {
    if (self.patternIndex == [self.pattern count])
    {
        if (self.patternShouldRepeat) {
            self.patternIndex = 0;
            [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(playPatternSegment) userInfo:nil repeats:NO];
            return;
        }
        else {
            [self stop];
            return;
        }
    }
    
    TGPatternSegment *segment = [self.pattern objectAtIndex:self.patternIndex];
    self.frequency = segment.frequency;
    if (!self.isPlaying) {
        [self start];
    }
    self.patternIndex += 1;
    self.patternTimer = [NSTimer scheduledTimerWithTimeInterval:segment.duration target:self selector:@selector(playPatternSegment) userInfo:nil repeats:NO];
}

- (void)cleanup {
    AudioSessionSetActive(false);
}

// from ToneGeneratorViewController:

OSStatus RenderTone(
                    void *inRefCon,
                    AudioUnitRenderActionFlags 	*ioActionFlags,
                    const AudioTimeStamp 		*inTimeStamp,
                    UInt32 						inBusNumber,
                    UInt32 						inNumberFrames,
                    AudioBufferList 			*ioData)

{
	// Get the tone parameters out of the view controller
	ToneGenerator *toneGenerator =
    (__bridge ToneGenerator *)inRefCon;
    double amplitude = toneGenerator.amplitude;
	double theta = toneGenerator.theta;
	double theta_increment = 2.0 * M_PI * toneGenerator.frequency / toneGenerator.sampleRate;
    
	// This is a mono tone generator so we only need the first buffer
	const int channel = 0;
	Float32 *buffer = (Float32 *)ioData->mBuffers[channel].mData;
	
	// Generate the samples
	for (UInt32 frame = 0; frame < inNumberFrames; frame++)
	{
		buffer[frame] = sin(theta) * amplitude;
		
		theta += theta_increment;
		if (theta > 2.0 * M_PI)
		{
			theta -= 2.0 * M_PI;
		}
	}
	
	// Store the theta back in the view controller
	toneGenerator.theta = theta;
    
	return noErr;
}

void ToneInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
	ToneGenerator *toneGenerator =
    (__bridge ToneGenerator *)inClientData;
	
	[toneGenerator stop];
}

- (void)createToneUnit
{
	// Configure the search parameters to find the default playback output unit
	// (called the kAudioUnitSubType_RemoteIO on iOS but
	// kAudioUnitSubType_DefaultOutput on Mac OS X)
	AudioComponentDescription defaultOutputDescription;
	defaultOutputDescription.componentType = kAudioUnitType_Output;
	defaultOutputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
	defaultOutputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	defaultOutputDescription.componentFlags = 0;
	defaultOutputDescription.componentFlagsMask = 0;
	
	// Get the default playback output unit
	AudioComponent defaultOutput = AudioComponentFindNext(NULL, &defaultOutputDescription);
	NSAssert(defaultOutput, @"Can't find default output");
	
	// Create a new unit based on this that we'll use for output
	OSErr err = AudioComponentInstanceNew(defaultOutput, &toneUnit);
	NSAssert1(toneUnit, @"Error creating unit: %hd", err);
	
	// Set our tone rendering function on the unit
	AURenderCallbackStruct input;
	input.inputProc = RenderTone;
	input.inputProcRefCon = (__bridge void *)(self);
	err = AudioUnitSetProperty(toneUnit,
                               kAudioUnitProperty_SetRenderCallback,
                               kAudioUnitScope_Input,
                               0,
                               &input,
                               sizeof(input));
	NSAssert1(err == noErr, @"Error setting callback: %hd", err);
	
	// Set the format to 32 bit, single channel, floating point, linear PCM
	const int four_bytes_per_float = 4;
	const int eight_bits_per_byte = 8;
	AudioStreamBasicDescription streamFormat;
	streamFormat.mSampleRate = _sampleRate;
	streamFormat.mFormatID = kAudioFormatLinearPCM;
	streamFormat.mFormatFlags =
    kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
	streamFormat.mBytesPerPacket = four_bytes_per_float;
	streamFormat.mFramesPerPacket = 1;
	streamFormat.mBytesPerFrame = four_bytes_per_float;
	streamFormat.mChannelsPerFrame = 1;
	streamFormat.mBitsPerChannel = four_bytes_per_float * eight_bits_per_byte;
	err = AudioUnitSetProperty (toneUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &streamFormat,
                                sizeof(AudioStreamBasicDescription));
	NSAssert1(err == noErr, @"Error setting stream format: %hd", err);
}

@end

@implementation TGPatternSegment

@end
