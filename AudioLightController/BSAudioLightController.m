//
//  BSAudioLightController.m
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//

@import AVFoundation;

#import "BSAudioLightController.h"

NSString* const BSAudioLightAvailabilityNotification = @"BSAudioLightAvailabilityNotification";

NSString* const BSAudioLightEnabledPrefKey = @"BSAudioLightEnabledPrefKey";

NSString* const BSAudioLightAvailabilityKey = @"BSAudioLightAvailabilityKey";
// https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingRouteChanges/HandlingRouteChanges.html#//apple_ref/doc/uid/TP40007875-CH12-SW1

// http://stackoverflow.com/questions/16869089/ios-audio-output-only-to-headphone-jack

@interface BSAudioLightController ()

-(NSURL*) soundFileOfAudioLightItem:(BSAudioLightItem) item;


@end

@implementation BSAudioLightController {
    NSMutableDictionary* _audioPlayers;
    NSUInteger _activeLightItems;
    NSNumber* _audioLightEnabled;
    BOOL _audioSessionActivated;
}

-(id)init
{
    if (self = [super init]) {
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(audioSessionRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        [nc addObserver:self selector:@selector(mediaServicesWereReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [nc addObserver:self selector:@selector(userDefaultsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];
#if TARGET_OS_IPHONE
        [nc addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif // TARGET_OS_IPHONE
       // initialize the audio session
        [self enabled];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


-(BOOL) enabled
{
    if (![self audioLightEnabled]) {
        return NO;
    }
    
    // check the current audio session and only play if it's the audio jack.
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription* currentRoute = [audioSession currentRoute];
    NSArray* outputs = [currentRoute outputs];
    if (outputs.count == 1 && [AVAudioSessionPortHeadphones isEqual:[outputs[0] portType]]) {
        if (!_audioSessionActivated) {
            NSError* audioCategoryError = nil;
            if ([audioSession setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDuckOthers error:&audioCategoryError]) {
                NSError* audioSessionActivationError = nil;
                if ([audioSession setActive:YES error:&audioSessionActivationError]) {
                    _audioSessionActivated = YES;
                } else {
                    NSLog(@"Error activating audio session: %@",audioSessionActivationError);
                }
            } else {
                NSLog(@"Error setting audio category: %@",audioCategoryError);
            }
        }
    } else {
        return NO;
    }

    return _audioSessionActivated;
}

-(BOOL) audioLightEnabled
{
    if (!_audioLightEnabled) {
        _audioLightEnabled = [[NSUserDefaults standardUserDefaults] objectForKey:BSAudioLightEnabledPrefKey];
    }
    return [_audioLightEnabled boolValue];
}

-(NSURL*) soundFileOfAudioLightItem:(BSAudioLightItem) item
{
    NSString* soundFile = nil;
    switch (item) {
        case BSAudioLightItemGreen:
            soundFile = @"timelight_green";
            break;
        case BSAudioLightItemYellow:
            soundFile = @"timelight_yellow";
            break;
        case BSAudioLightItemRed:
            soundFile = @"timelight_red";
            break;
        case BSAudioLightItemBuzzer:
            soundFile = @"timelight_buzzer";
            break;
        default:
            break;
    }
    if (soundFile) {
        return [[NSBundle mainBundle] URLForResource:soundFile withExtension:@"aiff"];
    }
    return nil;
}


-(AVAudioPlayer*) audioPlayerOfLightItem:(BSAudioLightItem) item
{
    if (!_audioPlayers) {
        _audioPlayers = [NSMutableDictionary dictionaryWithCapacity:4];
    }
    id itemObj = @(item);
    AVAudioPlayer* player = _audioPlayers[itemObj];
    if (!player) {
        NSURL* audioFileURL = [self soundFileOfAudioLightItem:item];
        NSError* error = nil;
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL error:&error];
        if (error) {
            NSLog(@"Error %@ loading file %@",error,audioFileURL);
            return nil;
        }
        _audioPlayers[itemObj] = player;
        player.numberOfLoops = -1; // loop indefinitely
    }
    return player;
}

-(void) playAudioLightItem:(BSAudioLightItem) item
{
    AVAudioSession* audioSession = [AVAudioSession sharedInstance];
    AVAudioSessionRouteDescription *currentRoute = [audioSession currentRoute];
    NSLog(@"route outputs: %@",[currentRoute outputs]);
    if(!_audioSessionActivated) {
        NSError* audioCategoryError = nil;
        if([audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioCategoryError]) {
            
        } else {
            NSLog(@"Failed to set audio category: %@",audioCategoryError);
        }
    }
    AVAudioPlayer* player = [self audioPlayerOfLightItem:item];
    [player play];
}

-(void) stopAudioLightItem:(BSAudioLightItem) item
{
    // don't use method since it will allocate on demand.
    AVAudioPlayer* player = _audioPlayers[@(item)];
    [player stop];
}


-(BOOL) refreshPlayers
{
    const BOOL audioCanPlay = [self enabled];
    void(^refreshPlayer)(BSAudioLightItem) = ^(BSAudioLightItem item) {
        BOOL itemPlaying = (_activeLightItems & item) != 0;
        if (itemPlaying ^ audioCanPlay) {
            [self stopAudioLightItem:item];
        } else if(itemPlaying && audioCanPlay) {
            [self playAudioLightItem:item];
        }
    };
    refreshPlayer(BSAudioLightItemGreen);
    refreshPlayer(BSAudioLightItemYellow);
    refreshPlayer(BSAudioLightItemRed);
    refreshPlayer(BSAudioLightItemBuzzer);
    return audioCanPlay;
}


-(void)audioLightItem:(BSAudioLightItem)item setActive:(BOOL)active
{
    if (active) {
        _activeLightItems |= item;
        if ([self enabled]) {
            [self playAudioLightItem:item];
        }
    } else {
        _activeLightItems &= ~item;
        [self stopAudioLightItem:item];
    }
}

#pragma mark Notification Handlers

#if TARGET_OS_IPHONE
-(void) applicationDidReceiveMemoryWarning:(NSNotification*) notification
{
    // release non-playing audio
    if (_audioPlayers.count > 0) {
        NSMutableArray* keysToRemove = [NSMutableArray arrayWithCapacity:_audioPlayers.count];
        [_audioPlayers enumerateKeysAndObjectsUsingBlock:^(id key, AVAudioPlayer* obj, BOOL *stop) {
            if (!obj.playing) {
                [keysToRemove addObject:key];
            }
        }];
        [_audioPlayers removeObjectsForKeys:keysToRemove];
    }
}
#endif // TARGET_OS_IPHONE

-(void) audioSessionRouteChanged:(NSNotification*) notification
{
    NSLog(@"Route changed: %@", notification.userInfo);
    // TODO: reactivate active items if audio jack is connected.
    BOOL audioCanPlay = [self refreshPlayers];
    
    NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(audioCanPlay)};
    [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:self userInfo:userInfo];
}


-(void) mediaServicesWereReset:(NSNotification*) notification
{
    NSLog(@"Media services reset.");
    _audioPlayers = nil;
    _audioSessionActivated = NO;
    BOOL available = [self refreshPlayers];
    NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(available)};
    [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:self userInfo:userInfo];
}

-(void) userDefaultsDidChange:(NSNotification*) notification
{
    NSNumber* updatedAudioLightEnabled =  [[NSUserDefaults standardUserDefaults] objectForKey:BSAudioLightEnabledPrefKey];
    if ([updatedAudioLightEnabled boolValue] != [_audioLightEnabled boolValue]) {
        _audioLightEnabled = updatedAudioLightEnabled;
        BOOL available = [self refreshPlayers];
        NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(available)};
        [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:self userInfo:userInfo];
    }
}
@end
