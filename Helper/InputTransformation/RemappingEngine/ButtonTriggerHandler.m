//
// --------------------------------------------------------------------------
// ButtonTriggerHandler.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2020
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "ButtonTriggerHandler.h"
#import "TransformationManager.h"
#import "ModifierManager.h"
#import "Constants.h"
#import "Actions.h"
#import "SharedUtility.h"
#import "ButtonTriggerGenerator.h"
#import "ButtonTriggerHandler.h"
#import "ButtonLandscapeAssessor.h"
#import "Utility_Transformation.h"

/// Figures out what effects to execute based on the triggers coming in from ButtonTriggerGenerator.m

@implementation ButtonTriggerHandler

#pragma mark - Handle triggers

+ (MFEventPassThroughEvaluation)handleButtonTriggerWithButton:(NSNumber *)button triggerType:(MFActionTriggerType)triggerType clickLevel:(NSNumber *)level device:(NSNumber *)devID {
    ///
    
    DDLogDebug(@"HANDLING BUTTON TRIGGER - button: %@, triggerType: %@, level: %@, devID: %@", button, @(triggerType), level, devID);
    
    /// Get remaps & apply overrides
    
    NSDictionary *remaps = TransformationManager.remaps;
    NSDictionary *modifiersActingOnThisTrigger = [ModifierManager getActiveModifiersForDevice:devID filterButton:button event:nil]; // The modifiers which act on the incoming button (the button can't modify itself so we filter it out)
    NSDictionary *remapsActingOnThisTrigger = Utility_Transformation.effectiveRemapsMethod_Override(remaps, modifiersActingOnThisTrigger); /// Take the defaults remaps and override them with the remapsForModifiersActingOnThisTrigger
    NSDictionary *remapsForModifiersActingOnThisTrigger = remaps[modifiersActingOnThisTrigger];
    ///     ^ `remapsForModifiersActingOnThisTrigger` is different from `remapsActingOnThisTrigger`, because it doesn't have any overrides applied to it.
    ///         For example if there is no modification for modifiersActingOnThisTrigger, then remapsForModifiersActingOnThisTrigger will be empty, while remapsActingOnThisTrigger will contain the default remaps.
    ///         (I'm using the words "modifications" and "remaps" interchangeably)
    
    /// Debug
    
//    DDLogDebug(@"\nActive mods: %@, \nremapsForActiveMods: %@", modifiersActingOnThisButton, remapsForModifiersActingOnThisButton);
    
    /// Let input pass through
    /// If no remaps exist for this button, let the CGEvent which caused this function call pass through
    ///     - Of course, that is only, if this function was invoked as a direct result of a physical button press - so if triggerType is buttonUp or buttonDown)
    
    if (triggerType == kMFActionTriggerTypeButtonDown || triggerType == kMFActionTriggerTypeButtonUp) {
        if (![ButtonLandscapeAssessor effectExistsForButton:button
                                                     remaps:remaps
                                            effectiveRemaps:remapsActingOnThisTrigger]) {
            DDLogDebug(@"No remaps exist for this button, letting event pass through");
            return kMFEventPassThroughApproval;
        }
    }
    
    /// Execute modifyingActions
    
    if (triggerType == kMFActionTriggerTypeButtonDown) {
        
    }
    
    /// Execute oneShotActions
    
    if (isTriggerForClickAction(triggerType)) {
        /// The incoming trigger is for a click action.
     
        /// Get active modifiers
        ///     We need them to assess mapping landscape (below)
        
        NSDictionary *activeModifiers = [ModifierManager getActiveModifiersForDevice:devID filterButton:nil event:nil];
        ///      ^ We need to check whether the incoming button is acting as a modifier to determine `effectForMouseDownStateOfThisLevelExists`,
        ///         so we can't use the variable `modifiersActingOnThisButton` defined above because it filters out the incoming button
        
        /**
        Assess the mapping landscape
            - Analyze which other mappings exist for the incoming button. Based on this info we can then determine which of the 3 click triggers we want to execute the click action on. We call this trigger the `targetTriggerType`.
                - The "3 click triggers" (mentioned above) are the triggers produced by ButtonTriggerGenerator on which a click action can be executed. Namely buttonUp, buttonDown, and levelTimerExpired.
            - It's unnecessary to figure out the targetTriggerType for click actions again and again, on every call of this function. We could precalculated everything, because the targetTriggerType only depends on the other mappings on the incoming button (aka the mappingLandscape).
                - However, when modifiers are active, (parts) of the mappingLandscape can be overridden. This would somewhat complicate the pre-calculation-approach, as we'd have to precalculate for each possible combination of modifications.
                - Anyways, the current approach (where we calculate the targetTriggerTypes for click actions again and again) is is plenty fast. So it's fine.
         */
        
        BOOL clickActionOfThisLevelExists;
        BOOL effectForMouseDownStateOfThisLevelExists;
        BOOL effectOfGreaterLevelExists;
        [ButtonLandscapeAssessor assessMappingLandscapeWithButton:button
                                                            level:level
                                                  activeModifiers:activeModifiers
                                          activeModifiersFiltered:modifiersActingOnThisTrigger
                                            effectiveRemapsMethod:Utility_Transformation.effectiveRemapsMethod_Override
                                                           remaps:remaps
                                                    thisClickDoBe:&clickActionOfThisLevelExists
                                                     thisDownDoBe:&effectForMouseDownStateOfThisLevelExists
                                                      greaterDoBe:&effectOfGreaterLevelExists];
        
        /// Find targetTriggerType based on mappingLandscape
        
        MFActionTriggerType targetTriggerType = kMFActionTriggerTypeNone;
        if (effectOfGreaterLevelExists) {
            targetTriggerType = kMFActionTriggerTypeLevelTimerExpired;
        } else if (effectForMouseDownStateOfThisLevelExists) {
            targetTriggerType = kMFActionTriggerTypeButtonUp;
        } else {
            targetTriggerType = kMFActionTriggerTypeButtonDown;
        }
        
        /// Execute action if incoming trigger matches target trigger
        
        if (triggerType == targetTriggerType) executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationClick,
                                                                                 devID,
                                                                                 button,
                                                                                 level,
                                                                                 modifiersActingOnThisTrigger,
                                                                                 remapsForModifiersActingOnThisTrigger,
                                                                                 remapsActingOnThisTrigger);
    } else if (triggerType == kMFActionTriggerTypeHoldTimerExpired) {
        /// Incoming trigger is for hold action
        /// -> Execute the hold action immediately. No need to calculate targetTriggerType like with the click triggers (above)
        
        executeClickOrHoldActionIfItExists(kMFButtonTriggerDurationHold,
                                           devID,
                                           button,
                                           level,
                                           modifiersActingOnThisTrigger,
                                           remapsForModifiersActingOnThisTrigger,
                                           remapsActingOnThisTrigger);
    } else {
        assert(false);
    }
    
    
    return kMFEventPassThroughRefusal;
    
}

#pragma mark - Execute oneShotActions

static void executeClickOrHoldActionIfItExists(NSString * _Nonnull duration,
                                               NSNumber * _Nonnull devID,
                                               NSNumber * _Nonnull button,
                                               NSNumber * _Nonnull level,
                                               NSDictionary *activeModifiers,
                                               NSDictionary *remapsForModifiersActingOnThisTrigger,
                                               NSDictionary *remapsActingOnThisTrigger) {
    
    NSArray *effectiveActionArray = remapsActingOnThisTrigger[button][level][duration];
    if (effectiveActionArray) { // click/hold action does exist for this button + level
        // // Add modificationPrecondition info for addMode. See TransformationManager -> AddMode for context
        if ([effectiveActionArray[0][kMFActionDictKeyType] isEqualToString: kMFActionDictTypeAddModeFeedback]) {
            effectiveActionArray[0][kMFRemapsKeyModificationPrecondition] = activeModifiers;
        }
        // Execute action
        [Actions executeActionArray:effectiveActionArray];
        // Notify triggering button
        [ButtonTriggerGenerator handleButtonHasHadDirectEffectWithDevice:devID button:button];
        // Notify modifying buttons if executed action depends on active modification
        NSArray *actionArrayFromActiveModification = remapsForModifiersActingOnThisTrigger[button][level][duration];
        BOOL actionStemsFromModification = [effectiveActionArray isEqual:actionArrayFromActiveModification];
        if (actionStemsFromModification) {
            [ModifierManager handleModifiersHaveHadEffect:devID];
        }
    }
}

#pragma mark - Execute modifyingActions

static void executeModifyingActionIfItExists(NSString * _Nonnull duration,
                                               NSNumber * _Nonnull devID,
                                               NSNumber * _Nonnull button,
                                               NSNumber * _Nonnull level,
                                               NSDictionary *activeModifiers,
                                               NSDictionary *remapsForModifiersActingOnThisTrigger,
                                               NSDictionary *remapsActingOnThisTrigger) {
    
    NSArray *effectiveActionArray = remapsActingOnThisTrigger[button][level][kMFButtonTriggerDurationModifying];
    if (effectiveActionArray) { // click/hold action does exist for this button + level
        // // Add modificationPrecondition info for addMode. See TransformationManager -> AddMode for context
        if ([effectiveActionArray[0][kMFActionDictKeyType] isEqualToString: kMFActionDictTypeAddModeFeedback]) {
            effectiveActionArray[0][kMFRemapsKeyModificationPrecondition] = activeModifiers;
        }
        // Execute action
        [Actions executeActionArray:effectiveActionArray];
        // Notify triggering button
        [ButtonTriggerGenerator handleButtonHasHadDirectEffectWithDevice:devID button:button];
        // Notify modifying buttons if executed action depends on active modification
        NSArray *actionArrayFromActiveModification = remapsForModifiersActingOnThisTrigger[button][level][kMFButtonTriggerDurationModifying];
        BOOL actionStemsFromModification = [effectiveActionArray isEqual:actionArrayFromActiveModification];
        if (actionStemsFromModification) {
            [ModifierManager handleModifiersHaveHadEffect:devID];
        }
    }
}

#pragma mark - Utility

static BOOL isTriggerForClickAction(MFActionTriggerType triggerType) {
    return triggerType == kMFActionTriggerTypeButtonDown ||
    triggerType == kMFActionTriggerTypeButtonUp ||
    triggerType == kMFActionTriggerTypeLevelTimerExpired;
}

@end
