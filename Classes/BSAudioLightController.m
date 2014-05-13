//
//  BSAudioLightController.m
//  TimeLightTester
//
//  Created by Sasmito Adibowo on 24-02-14.
//  Copyright (c) 2014 Basil Salad Software. All rights reserved.
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
//  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
//  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
//  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//


@import AVFoundation;

#if !TARGET_OS_IPHONE
#import <CoreAudio/CoreAudio.h>
#endif


#import "BSAudioLightController.h"

NSString* const BSAudioLightAvailabilityNotification = @"BSAudioLightAvailabilityNotification";
NSString* const BSAudioLightEnabledPrefKey = @"BSAudioLightEnabledPrefKey";
NSString* const BSAudioLightAvailabilityKey = @"BSAudioLightAvailabilityKey";


#if !TARGET_OS_IPHONE
const AudioObjectPropertyAddress BSAudioLightControllerSourceAddress = {
    kAudioDevicePropertyDataSource,
    kAudioDevicePropertyScopeOutput,
    kAudioObjectPropertyElementMaster
};
#endif


const float BSAudioLightDefaultFrequency = 5;

@interface BSAudioLightController ()

-(NSURL*) soundFileOfAudioLightItem:(BSAudioLightItem) item;

@end

@implementation BSAudioLightController {
    NSMutableDictionary* _audioPlayers;
    NSUInteger _activeLightItems;
    NSNumber* _audioLightEnabled;
    dispatch_queue_t _audioPlayerQueue;
    dispatch_source_t _twiddleDispatch;
#if TARGET_OS_IPHONE
    BOOL _audioSessionActivated;
#else
    AudioObjectID _audioObjectID;
    AudioObjectPropertyListenerBlock _audioObjectPropertyListener;
#endif // TARGET_OS_IPHONE
    BOOL _enabled;
}

-(id)init
{
    if (self = [super init]) {
        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
#if TARGET_OS_IPHONE
        [nc addObserver:self selector:@selector(audioSessionRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        [nc addObserver:self selector:@selector(mediaServicesWereReset:) name:AVAudioSessionMediaServicesWereResetNotification object:nil];
        [nc addObserver:self selector:@selector(applicationDidReceiveMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
#endif // TARGET_OS_IPHONE
        [nc addObserver:self selector:@selector(userDefaultsDidChange:) name:NSUserDefaultsDidChangeNotification object:nil];

       // initialize the audio session
        [self enabled];
        _twiddleFrequency = BSAudioLightDefaultFrequency;
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [self removeTwiddleDispatch];
#if !TARGET_OS_IPHONE
    [self removeAudioObjectPropertyListener];
#endif
}


#if !TARGET_OS_IPHONE
-(void) removeAudioObjectPropertyListener
{
    if (_audioObjectPropertyListener) {
        OSStatus result = AudioObjectRemovePropertyListenerBlock([self audioObjectID], &BSAudioLightControllerSourceAddress, dispatch_get_main_queue(), _audioObjectPropertyListener);
        if (result == noErr) {
            _audioObjectPropertyListener= nil;
        }
    }
}
#endif


-(void) removeTwiddleDispatch
{
    if (_twiddleDispatch) {
        dispatch_source_cancel(_twiddleDispatch);
        _twiddleDispatch = nil;
    }
}

-(BOOL) enabled
{
    dispatch_queue_t audioPlayerQueue = [self audioPlayerQueue];
    BSAudioLightController __weak* weakSelf = self;
    void(^updateEnabled)(BOOL) = ^(BOOL enabled){
        dispatch_async(audioPlayerQueue, ^{
            BSAudioLightController* strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            BOOL oldEnabled = strongSelf->_enabled;
            strongSelf->_enabled = enabled;
            if (oldEnabled != enabled) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(enabled)};
                    [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:strongSelf userInfo:userInfo];
                });
            }
        });
    };
    if (!_audioLightEnabled) {
        _audioLightEnabled = [[NSUserDefaults standardUserDefaults] objectForKey:BSAudioLightEnabledPrefKey];
    }

    if (![_audioLightEnabled boolValue]) {
        updateEnabled(NO);
#if !TARGET_OS_IPHONE
        [self removeAudioObjectPropertyListener];
#endif
        return NO;
    }
    
    BOOL enabled = YES;
    {
    // check the current audio session and only play if it's the audio jack.
#if TARGET_OS_IPHONE
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
            enabled = _audioSessionActivated;
        } else {
            enabled = NO;
        }
#else
        // http://stackoverflow.com/questions/14483083/how-to-get-notifications-when-the-headphones-are-plugged-in-out-mac
        const AudioObjectID audioObjectID = [self audioObjectID];
        UInt32 dataSourceId = 0;
        UInt32 dataSourceIdSize = sizeof(UInt32);
        AudioObjectGetPropertyData(audioObjectID, &BSAudioLightControllerSourceAddress, 0, NULL, &dataSourceIdSize, &dataSourceId);
        enabled = dataSourceId == 'hdpn';
    
        [self audioObjectPropertyListener];
#endif // TARGET_OS_IPHONE
    }
    
    updateEnabled(enabled);
    return enabled;
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
        player.numberOfLoops = -1; // loop indefinitely
        player.volume = 1;
        _audioPlayers[itemObj] = player;
    }
    return player;
}

-(void) playAudioLightItem:(BSAudioLightItem) item
{
    dispatch_async([self audioPlayerQueue], ^{
        AVAudioPlayer* player = [self audioPlayerOfLightItem:item];
        player.volume = 1;
        [player play];
    });
}

-(void) pauseAudioLightItem:(BSAudioLightItem) item
{
    dispatch_async([self audioPlayerQueue], ^{
        AVAudioPlayer* player = _audioPlayers[@(item)];
        [player pause];
    });
}

-(void) stopAudioLightItem:(BSAudioLightItem) item
{
    dispatch_async([self audioPlayerQueue], ^{
        AVAudioPlayer* player = _audioPlayers[@(item)];
        [player stop];
    });
}

-(void) reset
{
    if (_activeLightItems != 0) {
        _activeLightItems = 0;
        dispatch_async([self audioPlayerQueue], ^{
            [_audioPlayers enumerateKeysAndObjectsUsingBlock:^(id key, AVAudioPlayer* player, BOOL *stop) {
                if ([player isPlaying]) {
                    [player stop];
                }
            }];
            _audioPlayers = nil;
        });
    }
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
    
    const NSUInteger b = _activeLightItems;
    if (audioCanPlay && !(b && !(b & (b-1))) ) {
        // http://stackoverflow.com/questions/12483843/test-if-a-bitboard-have-only-one-bit-set-to-1
        // more than one bit is set.
        [self twiddleDispatchSource];
    } else {
        [self removeTwiddleDispatch];
    }

    return audioCanPlay;
}




-(void)audioLightItem:(BSAudioLightItem)item setActive:(BOOL)active
{
    if (active) {
        _activeLightItems |= item;
    } else {
        _activeLightItems &= ~item;
    }
    [self refreshPlayers];
}


#pragma mark Property Access

-(void)setTwiddleFrequency:(float)twiddleFrequency
{
    if (_twiddleFrequency != twiddleFrequency) {
        _twiddleFrequency = twiddleFrequency;
        if (_twiddleDispatch) {
            // restart twiddle
            [self removeTwiddleDispatch];
            [self twiddleDispatchSource];
        }
    }
}

-(dispatch_queue_t) audioPlayerQueue
{
    if (!_audioPlayerQueue) {
        // create a serial queue so that we can offload playing the audio at a different queue
        _audioPlayerQueue = dispatch_queue_create("com.basilsalad.audiolight.players",DISPATCH_QUEUE_SERIAL);
    }
    return _audioPlayerQueue;
}

-(dispatch_source_t) twiddleDispatchSource
{
    if (!_twiddleDispatch) {
        dispatch_source_t twiddleDispatch = _twiddleDispatch = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,[self audioPlayerQueue]);
        if (twiddleDispatch) {
            BSAudioLightController __weak* weakSelf = self;
            BSAudioLightItem __block currentLightedItem = 1;
            BSAudioLightItem __block previousLightedItem = 0;
            dispatch_source_set_event_handler(twiddleDispatch, ^{
                BSAudioLightController* strongSelf = weakSelf;
                if (!strongSelf) {
                    return;
                }
                if (!strongSelf->_enabled) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [strongSelf removeTwiddleDispatch];
                    });
                    return;
                }

                NSUInteger activeLightItems = strongSelf->_activeLightItems;
                
                if (currentLightedItem & activeLightItems) {
                    if (previousLightedItem && previousLightedItem != currentLightedItem) {
                        AVAudioPlayer* prevPlayer = [strongSelf audioPlayerOfLightItem:previousLightedItem];
                        prevPlayer.volume = 0;
                    }
                    AVAudioPlayer* curPlayer = [strongSelf audioPlayerOfLightItem:currentLightedItem];
                    curPlayer.volume = 1;
                    if (!curPlayer.playing) {
                        [curPlayer play];
                    }
                    previousLightedItem = currentLightedItem;
                }
                
                BSAudioLightItem seek = currentLightedItem << 1;
                do{
                    if (seek & activeLightItems) {
                        break;
                    }else if (seek & BSAudioLightItemMax) {
                        seek = 1;
                    } else {
                        seek <<= 1;
                    }
                } while (seek != currentLightedItem);
                currentLightedItem = seek;
            });
            float twiddleFrequency = self.twiddleFrequency;
            // in nanoseconds
            uint64_t twiddleInterval = round(NSEC_PER_SEC / twiddleFrequency);
            uint64_t twiddleLeeway =  twiddleInterval / 10;
            dispatch_source_set_timer(twiddleDispatch,  DISPATCH_TIME_NOW, twiddleInterval, twiddleLeeway);
            dispatch_resume(twiddleDispatch);
        }
    }
    return _twiddleDispatch;
}

#if !TARGET_OS_IPHONE
-(AudioObjectID) audioObjectID
{
    if (!_audioObjectID) {
        // TODO find the built-in output
        AudioObjectID defaultDevice = 0;
        UInt32 defaultSize = sizeof(AudioDeviceID);
        
        const AudioObjectPropertyAddress defaultAddress = {
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioObjectPropertyScopeGlobal,
            kAudioObjectPropertyElementMaster
        };

        OSStatus error = AudioObjectGetPropertyData(kAudioObjectSystemObject, &defaultAddress, 0, NULL, &defaultSize, &defaultDevice);
        
        if (error == noErr) {
            _audioObjectID = defaultDevice;
        }
    }
    return _audioObjectID;
}

-(AudioObjectPropertyListenerBlock) audioObjectPropertyListener
{
    if (!_audioObjectPropertyListener) {
        BSAudioLightController __weak* weakSelf = self;
         _audioObjectPropertyListener = ^(UInt32                 inNumberAddresses, const AudioObjectPropertyAddress    inAddresses[]) {
            BSAudioLightController* strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            // update the enabled flag
            [strongSelf refreshPlayers];
        };
        const AudioObjectID audioObjectID = [self audioObjectID];
        AudioObjectAddPropertyListenerBlock(audioObjectID, &BSAudioLightControllerSourceAddress, dispatch_get_main_queue(),_audioObjectPropertyListener);
    }
    return _audioObjectPropertyListener;
}

#endif // !TARGET_OS_IPHONE

#pragma mark Notification Handlers

#if TARGET_OS_IPHONE
-(void) applicationDidReceiveMemoryWarning:(NSNotification*) notification
{
    // release non-playing audio
    dispatch_async([self audioPlayerQueue], ^{
        if (_audioPlayers.count > 0) {
            NSMutableArray* keysToRemove = [NSMutableArray arrayWithCapacity:_audioPlayers.count];
            [_audioPlayers enumerateKeysAndObjectsUsingBlock:^(id key, AVAudioPlayer* obj, BOOL *stop) {
                if (!obj.playing) {
                    [keysToRemove addObject:key];
                }
            }];
            [_audioPlayers removeObjectsForKeys:keysToRemove];
        }
    });
}

-(void) audioSessionRouteChanged:(NSNotification*) notification
{
    [self refreshPlayers];
}

-(void) mediaServicesWereReset:(NSNotification*) notification
{
    dispatch_async([self audioPlayerQueue], ^{
        _audioPlayers = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            _audioSessionActivated = NO;
            [self refreshPlayers];
        });
    });
}

#endif // TARGET_OS_IPHONE


-(void) userDefaultsDidChange:(NSNotification*) notification
{
    NSNumber* updatedAudioLightEnabled =  [[NSUserDefaults standardUserDefaults] objectForKey:BSAudioLightEnabledPrefKey];
    if ([updatedAudioLightEnabled boolValue] != [_audioLightEnabled boolValue]) {
        _audioLightEnabled = updatedAudioLightEnabled;
        [self refreshPlayers];
    }
}
@end
