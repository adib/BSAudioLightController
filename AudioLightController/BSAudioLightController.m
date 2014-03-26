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

#import "BSAudioLightController.h"

NSString* const BSAudioLightAvailabilityNotification = @"BSAudioLightAvailabilityNotification";
NSString* const BSAudioLightEnabledPrefKey = @"BSAudioLightEnabledPrefKey";
NSString* const BSAudioLightAvailabilityKey = @"BSAudioLightAvailabilityKey";


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
    if (_twiddleDispatch) {
        dispatch_source_cancel(_twiddleDispatch);
        _twiddleDispatch = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
            strongSelf->_enabled = enabled;
        });
    };
    if (!_audioLightEnabled) {
        _audioLightEnabled = [[NSUserDefaults standardUserDefaults] objectForKey:BSAudioLightEnabledPrefKey];
    }
    

    if (![_audioLightEnabled boolValue]) {
        updateEnabled(NO);
        return NO;
    }
    
    BOOL enabled = YES;
#if TARGET_OS_IPHONE
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
        enabled = _audioSessionActivated;
    } else {
        enabled = NO;
    }
#else
    // TODO: handle Mac OS X audio jack check
    // http://stackoverflow.com/questions/14483083/how-to-get-notifications-when-the-headphones-are-plugged-in-out-mac
    
#endif // TARGET_OS_IPHONE
    
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
    [self checkTwiddleNeeded];
}


-(void) checkTwiddleNeeded
{
    // http://stackoverflow.com/questions/12483843/test-if-a-bitboard-have-only-one-bit-set-to-1
    const NSUInteger b = _activeLightItems;
    if (b && !(b & (b-1))) {
        // only one bit is set. no twiddle needed
        if (_twiddleDispatch) {
            dispatch_source_cancel(_twiddleDispatch);
            _twiddleDispatch = nil;
        }
        [self refreshPlayers];
    } else {
        // start twiddle
        [self twiddleDispatchSource];
    }
}

#pragma mark Property Access

-(void)setTwiddleFrequency:(float)twiddleFrequency
{
    if (_twiddleFrequency != twiddleFrequency) {
        _twiddleFrequency = twiddleFrequency;
        if (_twiddleDispatch) {
            // restart twiddle
            dispatch_source_cancel(_twiddleDispatch);
            _twiddleDispatch = nil;
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
                    dispatch_source_t td = strongSelf->_twiddleDispatch;
                    if (td) {
                        dispatch_source_cancel(td);
                        strongSelf->_twiddleDispatch = nil;
                    }
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
            uint64_t twiddleInterval = round(1000000000L / twiddleFrequency);
            uint64_t twiddleLeeway =  twiddleInterval / 10;
            dispatch_source_set_timer(twiddleDispatch,  DISPATCH_TIME_NOW, twiddleInterval, twiddleLeeway);
            dispatch_resume(twiddleDispatch);
        }
    }
    return _twiddleDispatch;
}

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
    BOOL audioCanPlay = [self refreshPlayers];
    [self checkTwiddleNeeded];
    NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(audioCanPlay)};
    [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:self userInfo:userInfo];
}


-(void) mediaServicesWereReset:(NSNotification*) notification
{
    dispatch_async([self audioPlayerQueue], ^{
        _audioPlayers = nil;
        
        dispatch_async(dispatch_get_main_queue(), ^{
#if TARGET_OS_IPHONE
            _audioSessionActivated = NO;
#endif // TARGET_OS_IPHONE
            BOOL available = [self refreshPlayers];
            NSDictionary* userInfo = @{BSAudioLightAvailabilityKey : @(available)};

            [[NSNotificationCenter defaultCenter] postNotificationName:BSAudioLightAvailabilityNotification object:self userInfo:userInfo];
        });
    });
}

#endif // TARGET_OS_IPHONE


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
