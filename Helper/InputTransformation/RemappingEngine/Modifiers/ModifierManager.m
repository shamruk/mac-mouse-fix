//
// --------------------------------------------------------------------------
// ModifierManager.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "Constants.h"

#import "ModifierManager.h"
#import "ButtonTriggerGenerator.h"
#import "TransformationManager.h"
#import "ModifiedDrag.h"
#import "DeviceManager.h"
#import "SharedUtility.h"
#import <os/signpost.h>


@implementation ModifierManager

/// Trigger driven modification -> when the trigger to be modified comes in, we check how we want to modify it
/// Modifier driven modification -> when the modification becomes active, we preemtively modify the triggers which it modifies
#pragma mark - Load

/// This used to be initialize but  that didn't execute until the first mouse buttons were pressed
/// Then it was load, but that led to '"Mac Mouse Fix Helper" would like to receive keystrokes from any application' prompt. (I think)
+ (void)load_Manual {
    if (self == [ModifierManager class]) {
        // Create keyboard modifier event tap
        CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
        _keyboardModifierEventTap = CGEventTapCreate(kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly, mask, handleKeyboardModifiersHaveChanged, NULL);
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _keyboardModifierEventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        CFRelease(runLoopSource);
        // Enable/Disable eventTap based on TransformationManager.remaps
        CGEventTapEnable(_keyboardModifierEventTap, false); // Disable eventTap first (Might prevent `_keyboardModifierEventTap` from always being called twice - Nope doesn't make a difference)
        toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
        
        // Re-toggle keyboard modifier callbacks whenever TransformationManager.remaps changes
        // TODO:! Test if this works
        [NSNotificationCenter.defaultCenter addObserverForName:kMFNotifCenterNotificationNameRemapsChanged
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification * _Nonnull note) {
            DDLogDebug(@"Received notification that remaps have changed");
            toggleModifierEventTapBasedOnRemaps(TransformationManager.remaps);
        }];
    }
}
#pragma mark - Modifier driven modification

jhuj

#pragma mark Send Feedback

+ (void)handleModifiersHaveHadEffect:(NSNumber *)devID {
    
    NSDictionary *activeModifiers = [self getActiveModifiersForDevice:devID filterButton:nil event:nil];
        
    // Notify all active button modifiers that they have had an effect
    for (NSDictionary *buttonPrecondDict in activeModifiers[kMFModificationPreconditionKeyButtons]) {
        NSNumber *precondButtonNumber = buttonPrecondDict[kMFButtonModificationPreconditionKeyButtonNumber];
        [ButtonTriggerGenerator handleButtonHasHadEffectAsModifierWithDevice:devID button:precondButtonNumber];
    }
}

#pragma mark - Trigger driven modification
// Explanation: Modification of most triggers is *trigger driven*.
//      That means only once the trigger comes in, we'll check for active modifiers and then apply those to the incoming trigger.
//      But sometimes its not feasible to always listen for triggers (for example in the case of modified drags, for performance reasons)
//      In those cases we'll use *modifier driven* modification.
//      That means we listen for changes to the active modifiers and when they match a modifications' precondition, we'll initialize the modification components which are modifier driven.
//      Then, when they do send their first trigger, they'll call modifierDrivenModificationHasBeenUsedWithDevice which will in turn notify the modifying buttons that they've had an effect
// \discussion If you pass in an a CGEvent via the `event` argument, the returned keyboard modifiers will be more up-to-date. This is sometimes necessary to get correct data when calling this right after the keyboard modifiers have changed.
// Analyzing with os_signpost reveals this is called 9 times per button click and takes around 20% of the time.
//      That's over a third of the time which is used by our code (I think) - We should look into optimizing this (if we have too much time - the program is plenty fast). Maybe caching the values or calling it less, or making it faster.
+ (NSDictionary *)getActiveModifiersForDevice:(NSNumber *)devID filterButton:(NSNumber * _Nullable)filteredButton event:(CGEventRef _Nullable) event {
    
//    DDLogDebug(@"ActiveModifiers requested by: %s\n", SharedUtility.callerInfo.UTF8String);
    
    NSMutableDictionary *outDict = [NSMutableDictionary dictionary];
    
    NSUInteger kb = [self getActiveKeyboardModifiersWithEvent:event];
    NSMutableArray *btn = [ButtonTriggerGenerator getActiveButtonModifiersForDevice:devID].mutableCopy;
    if (filteredButton != nil && btn.count != 0) {
        NSIndexSet *filterIndexes = [btn indexesOfObjectsPassingTest:^BOOL(NSDictionary *_Nonnull dict, NSUInteger idx, BOOL * _Nonnull stop) {
            return [dict[kMFButtonModificationPreconditionKeyButtonNumber] isEqualToNumber:filteredButton];
        }];
        [btn removeObjectsAtIndexes:filterIndexes];
    }
    // ^ filteredButton is used by `handleButtonTriggerWithButton:trigger:level:device:` to remove modification state caused by the button causing the current input trigger.
        // Don't fully understand this but I think a button shouldn't modify its own triggers.
        // You can't even produce a mouse down trigger without activating the button as a modifier... Just doesn't make sense.
    
    if (kb != 0) {
        outDict[kMFModificationPreconditionKeyKeyboard] = @(kb);
    }
    if (btn.count != 0) {
        outDict[kMFModificationPreconditionKeyButtons] = btn;
    }
    
    return outDict;
}

+ (NSUInteger) getActiveKeyboardModifiersWithEvent:(CGEventRef _Nullable)event {
    
    BOOL passedInEventIsNil = NO;
    if (event == nil) {
        passedInEventIsNil = YES;
        event = CGEventCreate(NULL);
    }
    
    uint64_t mask = 0xFF0000; // Only lets bits 16-23 through
    /// NSEventModifierFlagDeviceIndependentFlagsMask == 0xFFFF0000 -> it only allows bits 16 - 31.
    ///  But bits 24 - 31 contained weird stuff which messed up the return value and modifiers are only on bits 16-23, so we defined our own mask
    
    mask &= ~kCGEventFlagMaskAlphaShift;
    /// Ignore caps lock. Otherwise modfifications won't work normally when caps lock is enabled.
    ///     Maybe we need to ignore caps lock in other places, too make this work properly but I don't think so
    
    CGEventFlags modifierFlags = CGEventGetFlags(event) & mask;
    
    if (passedInEventIsNil) CFRelease(event);
    
    return modifierFlags;
}

@end
