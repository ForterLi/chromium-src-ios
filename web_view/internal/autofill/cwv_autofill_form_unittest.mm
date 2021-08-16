// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web_view/internal/autofill/cwv_autofill_form_internal.h"

#import <Foundation/Foundation.h>
#include <memory>

#include "base/path_service.h"
#include "base/strings/sys_string_conversions.h"
#include "components/autofill/core/browser/autofill_test_utils.h"
#include "components/autofill/core/browser/form_structure.h"
#include "ios/web_view/test/test_with_locale_and_resources.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "ui/base/resource/resource_bundle.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios_web_view {

using CWVAutofillFormTest = TestWithLocaleAndResources;

// Tests CWVAutofillForm initialization.
TEST_F(CWVAutofillFormTest, Initialization) {
  // Load resources that are generated by the WebView build.
  // The resources contain the configuration for the PatternProvider.
  base::FilePath pak_path;
  base::PathService::Get(base::DIR_MODULE, &pak_path);
  pak_path = pak_path.AppendASCII("web_view_resources.pak");
  ui::ResourceBundle::GetSharedInstance().AddDataPackFromPath(
      pak_path, ui::kScaleFactorNone);

  autofill::FormData form_data;
  autofill::test::CreateTestAddressFormData(&form_data);
  std::unique_ptr<autofill::FormStructure> form_structure =
      std::make_unique<autofill::FormStructure>(form_data);
  form_structure->DetermineHeuristicTypes(nullptr, nullptr);
  CWVAutofillForm* form =
      [[CWVAutofillForm alloc] initWithFormStructure:*form_structure];
  EXPECT_NSEQ(base::SysUTF16ToNSString(form_data.name), form.name);
  EXPECT_TRUE(form.type & CWVAutofillFormTypeAddresses);
  EXPECT_FALSE(form.type & CWVAutofillFormTypeCreditCards);
  EXPECT_FALSE(form.type & CWVAutofillFormTypePasswords);
}

}  // namespace ios_web_view
