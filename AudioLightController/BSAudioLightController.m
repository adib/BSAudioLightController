//
//  BSAudioLightController.m
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//

@import AVFoundation;

#import "BSAudioLightController.h"

NSString* const BSAudioLightControllerAvailabilityNotification = @"BSAudioLightControllerAvailabilityNotification";

NSString* const BSAudioLightEnabledPrefKey = @"BSAudioLightEnabledPrefKey";

NSString* const BSAudioLightControllerAvailabilityKey = @"BSAudioLightControllerAvailabilityKey";
// https://developer.apple.com/library/ios/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingRouteChanges/HandlingRouteChanges.html#//apple_ref/doc/uid/TP40007875-CH12-SW1

// http://stackoverflow.com/questions/16869089/ios-audio-output-only-to-headphone-jack

@interface BSAudioLightController ()

-(NSURL*) soundFileOfAudioLightItem:(BSAudioLightItem) item;


@end

@implementation BSAudioLightController {
    NSMutableDictionary* _audioPlayers;
    BSAudioLightItem _activeLightItems;
}

-(id)init
{
    if (self = [super init]) {
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(audioSessionRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        [nc addObserver:self selector:@selector(mediaServicesWereReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
#if TARGET_OS_IPHONE
        [nc addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif // TARGET_OS_IPHONE
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        NSLog(@"audio route: %@",audioSession.currentRoute);
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:BSAudioLightEnabledPrefKey]) {
        return;
    }
    // TODO: check the current audio session and only play if it's the audio jack.
    
    AVAudioPlayer* player = [self audioPlayerOfLightItem:item];
    [player play];
}

-(void) stopAudioLightItem:(BSAudioLightItem) item
{
    // don't use method since it will allocate on demand.
    AVAudioPlayer* player = _audioPlayers[@(item)];
    [player stop];
}

-(void) reactivatePlayer
{
    // TODO: re-activate currently playing audio light items
}


-(void)audioLightItem:(BSAudioLightItem)item setActive:(BOOL)active
{
    if (active) {
        _activeLightItems &= item;
        [self playAudioLightItem:item];
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
}


-(void) mediaServicesWereReset:(NSNotification*) notification
{
    NSLog(@"Media services reset.");
    // TODO: reactivate active items
}
@end
