// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/content_suggestions/content_suggestions_constants.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

NSString* const kContentSuggestionsCollectionIdentifier =
    @"ContentSuggestionsCollectionIdentifier";

NSString* const kContentSuggestionsLearnMoreIdentifier = @"Learn more";

NSString* const kContentSuggestionsMostVisitedAccessibilityIdentifierPrefix =
    @"contentSuggestionsMostVisitedAccessibilityIdentifierPrefix";

NSString* const kContentSuggestionsShortcutsAccessibilityIdentifierPrefix =
    @"contentSuggestionsShortcutsAccessibilityIdentifierPrefix";

const CGFloat kMostVisitedBottomMargin = 13;

const NSUInteger kMaxTrendingQueries = 4;
