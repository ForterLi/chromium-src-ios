// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_FIRST_RUN_DEFAULT_BROWSER_PROMO_FIELD_TRIAL_H_
#define IOS_CHROME_BROWSER_UI_FIRST_RUN_DEFAULT_BROWSER_PROMO_FIELD_TRIAL_H_

#include "base/metrics/field_trial.h"

class PrefRegistrySimple;
class PrefService;

namespace base {
class FeatureList;
}  // namespace base

namespace fre_default_browser_promo_field_trial {

// Returns true if the user is in the group that will show the default browser
// screen in first run (FRE) without activate cooldown of other default browser
// promos.
bool IsInFirstRunDefaultBrowserWithoutDelayingOtherPromosGroup();

// Returns true if the user is in the group that will show the default browser
// screen in first run (FRE) and activate cooldown of other default browser
// promos.
bool IsInFirstRunDefaultBrowserWithDelayingOtherPromosGroup();

// Returns true if the user is in the group that will show the default browser
// screen in first run (FRE) only.
bool IsInDefaultBrowserPromoAtFirstRunOnlyGroup();

// Returns true if the default browser screen in FRE is enabled.
bool IsFREDefaultBrowserScreenEnabled();

// Registers the local state pref used to manage grouping for this field trial.
void RegisterLocalStatePrefs(PrefRegistrySimple* registry);

// Creates a field trial to control the default browser screen feature. The
// trial is client controlled because one arm of the experiment involves
// changing the user experience during First Run.
//
// The trial group chosen on first run is persisted to local state prefs.
void Create(const base::FieldTrial::EntropyProvider& low_entropy_provider,
            base::FeatureList* feature_list,
            PrefService* local_state);

}  // namespace fre_default_browser_promo_field_trial

#endif  // IOS_CHROME_BROWSER_UI_FIRST_RUN_DEFAULT_BROWSER_PROMO_FIELD_TRIAL_H_