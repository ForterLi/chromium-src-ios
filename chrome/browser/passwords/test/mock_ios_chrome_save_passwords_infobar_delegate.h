// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_PASSWORDS_TEST_MOCK_IOS_CHROME_SAVE_PASSWORDS_INFOBAR_DELEGATE_H_
#define IOS_CHROME_BROWSER_PASSWORDS_TEST_MOCK_IOS_CHROME_SAVE_PASSWORDS_INFOBAR_DELEGATE_H_

#import <Foundation/Foundation.h>
#include <memory>

#include "components/autofill/core/common/password_form.h"
#import "ios/chrome/browser/passwords/ios_chrome_save_password_infobar_delegate.h"
#include "testing/gmock/include/gmock/gmock.h"

// Mock queue observer.
class MockIOSChromeSavePasswordInfoBarDelegate
    : public IOSChromeSavePasswordInfoBarDelegate {
 public:
  MockIOSChromeSavePasswordInfoBarDelegate(
      bool is_sync_user,
      bool password_update,
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_save);
  ~MockIOSChromeSavePasswordInfoBarDelegate() override;

  // Factory method that creates a mock save password delegate for pending
  // with credentials |username| and |password|.
  static std::unique_ptr<MockIOSChromeSavePasswordInfoBarDelegate> Create(
      NSString* username,
      NSString* password);

  MOCK_METHOD0(InfoBarDismissed, void());
  MOCK_METHOD0(Accept, bool());
  MOCK_METHOD1(InfobarPresenting, void(bool automatic));
  MOCK_METHOD0(InfobarDismissed, void());

 private:
  explicit MockIOSChromeSavePasswordInfoBarDelegate(
      std::unique_ptr<autofill::PasswordForm> form);

  std::unique_ptr<autofill::PasswordForm> form_;
};

#endif  // IOS_CHROME_BROWSER_PASSWORDS_TEST_MOCK_IOS_CHROME_SAVE_PASSWORDS_INFOBAR_DELEGATE_H_
