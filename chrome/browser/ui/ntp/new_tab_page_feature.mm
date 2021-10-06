// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/ntp/new_tab_page_feature.h"

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_feature.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

const base::Feature kEnableDiscoverFeedPreview{
    "EnableDiscoverFeedPreview", base::FEATURE_DISABLED_BY_DEFAULT};

const base::Feature kEnableDiscoverFeedAppFlows{
    "EnableDiscoverFeedAppFlows", base::FEATURE_DISABLED_BY_DEFAULT};

const base::Feature kEnableNTPMemoryEnhancement{
    "EnableNTPMemoryEnhancement", base::FEATURE_ENABLED_BY_DEFAULT};

const base::Feature kEnableDiscoverFeedDiscoFeedEndpoint{
    "EnableDiscoFeedEndpoint", base::FEATURE_DISABLED_BY_DEFAULT};

const base::Feature kEnableDiscoverFeedStaticResourceServing{
    "EnableDiscoverFeedStaticResourceServing",
    base::FEATURE_DISABLED_BY_DEFAULT};

const char kDiscoverFeedSRSReconstructedTemplatesEnabled[] =
    "DiscoverFeedSRSReconstructedTemplatesEnabled";

const char kDiscoverFeedSRSPreloadTemplatesEnabled[] =
    "DiscoverFeedSRSPreloadTemplatesEnabled";

bool IsDiscoverFeedPreviewEnabled() {
  return base::FeatureList::IsEnabled(kEnableDiscoverFeedPreview);
}

bool IsDiscoverFeedAppFlowsEnabled() {
  return base::FeatureList::IsEnabled(kEnableDiscoverFeedAppFlows);
}
