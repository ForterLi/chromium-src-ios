// Copyright 2013 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_PUBLIC_PROVIDER_CHROME_BROWSER_STRING_PROVIDER_H_
#define IOS_PUBLIC_PROVIDER_CHROME_BROWSER_STRING_PROVIDER_H_

#include <string>

#include "base/strings/string16.h"

namespace ios {

// A class that provides access to localized strings defined in
// src/ios_internal/ from code that lives in src/chrome/browser/ but has not
// been moved upstream yet.
//
// Situations where forked code needs access to downstream strings should be
// temporary and methods should be removed when either
//   1) the code is moved to upstream (in which case the strings should also be
//      moved to upstream into src/grit/generated_resources.grd), or
//   2) the downstream implementation changes to match upstream so the string
//      is no longer necessary.
class StringProvider {
 public:
  StringProvider();
  virtual ~StringProvider();

  // Returns the product name (e.g. "Google Chrome").
  virtual base::string16 GetProductName();
};

}  // namespace ios

#endif  // IOS_PUBLIC_PROVIDER_CHROME_BROWSER_STRING_PROVIDER_H_
