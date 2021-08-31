// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/public/provider/chrome/browser/voice/voice_search_provider.h"

#import "ios/public/provider/chrome/browser/voice/voice_search_controller.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

bool VoiceSearchProvider::IsVoiceSearchEnabled() const {
  return false;
}

NSArray* VoiceSearchProvider::GetAvailableLanguages() const {
  return @[];
}

scoped_refptr<VoiceSearchController>
VoiceSearchProvider::CreateVoiceSearchController(Browser* browser) const {
  return scoped_refptr<VoiceSearchController>(nullptr);
}
