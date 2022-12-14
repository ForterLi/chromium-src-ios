// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/passwords/ios_chrome_password_check_manager.h"

#include <memory>
#include <string>
#include <vector>

#include "base/bind.h"
#include "base/memory/scoped_refptr.h"
#include "base/strings/strcat.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/string_piece.h"
#include "base/strings/string_util.h"
#include "base/strings/utf_string_conversions.h"
#include "base/test/bind.h"
#include "base/test/scoped_feature_list.h"
#include "base/time/time.h"
#include "components/password_manager/core/browser/bulk_leak_check_service.h"
#include "components/password_manager/core/browser/mock_bulk_leak_check_service.h"
#include "components/password_manager/core/browser/password_form.h"
#include "components/password_manager/core/browser/password_manager_test_utils.h"
#include "components/password_manager/core/browser/test_password_store.h"
#include "components/password_manager/core/common/password_manager_features.h"
#include "components/password_manager/core/common/password_manager_pref_names.h"
#include "components/prefs/pref_registry_simple.h"
#include "components/prefs/testing_pref_service.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/passwords/ios_chrome_bulk_leak_check_service_factory.h"
#include "ios/chrome/browser/passwords/ios_chrome_password_check_manager_factory.h"
#include "ios/chrome/browser/passwords/ios_chrome_password_store_factory.h"
#include "ios/web/public/test/web_task_environment.h"
#include "testing/gmock/include/gmock/gmock.h"
#include "testing/gtest/include/gtest/gtest.h"
#include "testing/platform_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
constexpr char kExampleCom[] = "https://example.com";

constexpr char16_t kUsername116[] = u"alice";
constexpr char16_t kUsername216[] = u"bob";

constexpr char16_t kPassword116[] = u"s3cre3t";

using password_manager::BulkLeakCheckServiceInterface;
using password_manager::CredentialUIEntry;
using password_manager::InsecureCredential;
using password_manager::InsecureType;
using password_manager::IsLeaked;
using password_manager::LeakCheckCredential;
using password_manager::MockBulkLeakCheckService;
using password_manager::PasswordForm;
using password_manager::TestPasswordStore;
using ::testing::AllOf;
using ::testing::ElementsAre;
using ::testing::Field;
using ::testing::IsEmpty;
using ::testing::Pair;
using ::testing::StrictMock;

struct MockPasswordCheckManagerObserver
    : IOSChromePasswordCheckManager::Observer {
  MOCK_METHOD(void, CompromisedCredentialsChanged, (), (override));
  MOCK_METHOD(void,
              PasswordCheckStatusChanged,
              (PasswordCheckState),
              (override));
};

scoped_refptr<TestPasswordStore> CreateAndUseTestPasswordStore(
    ChromeBrowserState* _browserState) {
  return base::WrapRefCounted(static_cast<password_manager::TestPasswordStore*>(
      IOSChromePasswordStoreFactory::GetInstance()
          ->SetTestingFactoryAndUse(
              _browserState,
              base::BindRepeating(&password_manager::BuildPasswordStore<
                                  web::BrowserState, TestPasswordStore>))
          .get()));
}

MockBulkLeakCheckService* CreateAndUseBulkLeakCheckService(
    ChromeBrowserState* _browserState) {
  return static_cast<MockBulkLeakCheckService*>(
      IOSChromeBulkLeakCheckServiceFactory::GetInstance()
          ->SetTestingFactoryAndUse(
              _browserState, base::BindLambdaForTesting([](web::BrowserState*) {
                return std::unique_ptr<KeyedService>(
                    std::make_unique<MockBulkLeakCheckService>());
              })));
}

PasswordForm MakeSavedPassword(
    base::StringPiece signon_realm,
    base::StringPiece16 username,
    base::StringPiece16 password = kPassword116,
    base::StringPiece16 username_element = base::StringPiece16()) {
  PasswordForm form;
  form.signon_realm = std::string(signon_realm);
  form.username_value = std::u16string(username);
  form.password_value = std::u16string(password);
  form.username_element = std::u16string(username_element);
  form.in_store = PasswordForm::Store::kProfileStore;
  // TODO(crbug.com/1223022): Once all places that operate changes on forms
  // via UpdateLogin properly set |password_issues|, setting them to an empty
  // map should be part of the default constructor.
  form.password_issues =
      base::flat_map<InsecureType, password_manager::InsecurityMetadata>();
  return form;
}

void AddIssueToForm(PasswordForm* form,
                    InsecureType type = InsecureType::kLeaked,
                    base::TimeDelta time_since_creation = base::TimeDelta(),
                    bool is_muted = false) {
  form->password_issues.insert_or_assign(
      type, password_manager::InsecurityMetadata(
                base::Time::Now() - time_since_creation,
                password_manager::IsMuted(is_muted)));
}

class IOSChromePasswordCheckManagerTest : public PlatformTest {
 public:
  IOSChromePasswordCheckManagerTest()
      : browser_state_(TestChromeBrowserState::Builder().Build()),
        bulk_leak_check_service_(
            CreateAndUseBulkLeakCheckService(browser_state_.get())),
        store_(CreateAndUseTestPasswordStore(browser_state_.get())) {
    manager_ = IOSChromePasswordCheckManagerFactory::GetForBrowserState(
        browser_state_.get());
  }

  void RunUntilIdle() { task_env_.RunUntilIdle(); }

  void FastForwardBy(base::TimeDelta time) { task_env_.FastForwardBy(time); }

  ChromeBrowserState* browser_state() { return browser_state_.get(); }
  TestPasswordStore& store() { return *store_; }
  MockBulkLeakCheckService* service() { return bulk_leak_check_service_; }
  IOSChromePasswordCheckManager& manager() { return *manager_; }

 private:
  web::WebTaskEnvironment task_env_{
      web::WebTaskEnvironment::Options::DEFAULT,
      base::test::TaskEnvironment::TimeSource::MOCK_TIME};
  std::unique_ptr<ChromeBrowserState> browser_state_;
  MockBulkLeakCheckService* bulk_leak_check_service_;
  scoped_refptr<TestPasswordStore> store_;
  scoped_refptr<IOSChromePasswordCheckManager> manager_;
};
}  // namespace

// Sets up the password store with a password and unmuted compromised
// credential. Verifies that the result is matching expectation.
TEST_F(IOSChromePasswordCheckManagerTest, GetUnmutedCompromisedCredentials) {
  PasswordForm form = MakeSavedPassword(kExampleCom, kUsername116);
  AddIssueToForm(&form, InsecureType::kLeaked, base::Minutes(1));
  store().AddLogin(form);
  RunUntilIdle();

  EXPECT_THAT(manager().GetUnmutedCompromisedCredentials(),
              ElementsAre(CredentialUIEntry(form)));
}

// Test that we don't create an entry in the password store if IsLeaked is
// false.
TEST_F(IOSChromePasswordCheckManagerTest, NoLeakedFound) {
  store().AddLogin(MakeSavedPassword(kExampleCom, kUsername116, kPassword116));
  RunUntilIdle();

  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnCredentialDone(LeakCheckCredential(kUsername116, kPassword116),
                         IsLeaked(false));
  RunUntilIdle();

  EXPECT_THAT(manager().GetUnmutedCompromisedCredentials(), IsEmpty());
}

// Test that a found leak creates a compromised credential in the password
// store.
TEST_F(IOSChromePasswordCheckManagerTest, OnLeakFoundCreatesCredential) {
  PasswordForm form = MakeSavedPassword(kExampleCom, kUsername116);
  store().AddLogin(MakeSavedPassword(kExampleCom, kUsername116, kPassword116));
  RunUntilIdle();

  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnCredentialDone(LeakCheckCredential(kUsername116, kPassword116),
                         IsLeaked(true));
  RunUntilIdle();

  AddIssueToForm(&form, InsecureType::kLeaked, base::Minutes(0));
  EXPECT_THAT(manager().GetUnmutedCompromisedCredentials(),
              ElementsAre(CredentialUIEntry(form)));
}

// Verifies that the case where the user has no saved passwords is reported
// correctly.
TEST_F(IOSChromePasswordCheckManagerTest, GetPasswordCheckStatusNoPasswords) {
  EXPECT_EQ(PasswordCheckState::kNoPasswords,
            manager().GetPasswordCheckState());
}

// Verifies that the case where the user has saved passwords is reported
// correctly.
TEST_F(IOSChromePasswordCheckManagerTest, GetPasswordCheckStatusIdle) {
  store().AddLogin(MakeSavedPassword(kExampleCom, kUsername116));
  RunUntilIdle();

  EXPECT_EQ(PasswordCheckState::kIdle, manager().GetPasswordCheckState());
}

// Checks that the default kLastTimePasswordCheckCompleted pref value is
// treated as no completed run yet.
TEST_F(IOSChromePasswordCheckManagerTest,
       LastTimePasswordCheckCompletedNotSet) {
  EXPECT_EQ(base::Time(), manager().GetLastPasswordCheckTime());
}

// Checks that a transition into the idle state after starting a check results
// in resetting the kLastTimePasswordCheckCompleted pref to the current time.
TEST_F(IOSChromePasswordCheckManagerTest, LastTimePasswordCheckCompletedReset) {
  manager().StartPasswordCheck();
  RunUntilIdle();

  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnStateChanged(BulkLeakCheckServiceInterface::State::kIdle);

  EXPECT_THAT(base::Time::Now(), manager().GetLastPasswordCheckTime());
}

// Tests whether adding and removing an observer works as expected.
TEST_F(IOSChromePasswordCheckManagerTest,
       NotifyObserversAboutCompromisedCredentialChanges) {
  PasswordForm form = MakeSavedPassword(kExampleCom, kUsername116);
  store().AddLogin(form);
  RunUntilIdle();

  StrictMock<MockPasswordCheckManagerObserver> observer;
  manager().AddObserver(&observer);

  // Adding a compromised credential should notify observers.
  EXPECT_CALL(observer, PasswordCheckStatusChanged);
  EXPECT_CALL(observer, CompromisedCredentialsChanged);
  AddIssueToForm(&form, InsecureType::kLeaked, base::Minutes(1));
  store().UpdateLogin(form);
  RunUntilIdle();

  // After an observer is removed it should no longer receive notifications.
  manager().RemoveObserver(&observer);
  EXPECT_CALL(observer, CompromisedCredentialsChanged).Times(0);
  AddIssueToForm(&form, InsecureType::kPhished, base::Minutes(1));
  store().UpdateLogin(form);
  RunUntilIdle();
}

// Tests whether adding and removing an observer works as expected.
TEST_F(IOSChromePasswordCheckManagerTest, NotifyObserversAboutStateChanges) {
  store().AddLogin(MakeSavedPassword(kExampleCom, kUsername116));
  RunUntilIdle();
  StrictMock<MockPasswordCheckManagerObserver> observer;
  manager().AddObserver(&observer);

  EXPECT_CALL(observer, PasswordCheckStatusChanged(PasswordCheckState::kIdle));
  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnStateChanged(BulkLeakCheckServiceInterface::State::kIdle);

  RunUntilIdle();

  EXPECT_EQ(PasswordCheckState::kIdle, manager().GetPasswordCheckState());

  // After an observer is removed it should no longer receive notifications.
  manager().RemoveObserver(&observer);
  EXPECT_CALL(observer, PasswordCheckStatusChanged).Times(0);
  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnStateChanged(BulkLeakCheckServiceInterface::State::kRunning);
  RunUntilIdle();
}

// Tests expected delay is being added.
TEST_F(IOSChromePasswordCheckManagerTest, CheckFinishedWithDelay) {
  store().AddLogin(MakeSavedPassword(kExampleCom, kUsername116));

  RunUntilIdle();
  StrictMock<MockPasswordCheckManagerObserver> observer;
  manager().AddObserver(&observer);
  manager().StartPasswordCheck();
  RunUntilIdle();

  EXPECT_CALL(observer, PasswordCheckStatusChanged(PasswordCheckState::kIdle))
      .Times(0);
  static_cast<BulkLeakCheckServiceInterface::Observer*>(&manager())
      ->OnStateChanged(BulkLeakCheckServiceInterface::State::kIdle);
  FastForwardBy(base::Seconds(1));

  EXPECT_CALL(observer, PasswordCheckStatusChanged(PasswordCheckState::kIdle))
      .Times(0);
  FastForwardBy(base::Seconds(1));

  EXPECT_CALL(observer, PasswordCheckStatusChanged(PasswordCheckState::kIdle))
      .Times(1);
  FastForwardBy(base::Seconds(1));
  manager().RemoveObserver(&observer);
}

// Tests that that the correct number of compromised credentials is returned.
TEST_F(IOSChromePasswordCheckManagerTest, CheckCompromisedCredentialsCount) {
  // Enable unmuted compromised credential feature.
  base::test::ScopedFeatureList featureList;
  featureList.InitAndEnableFeature(
      password_manager::features::kMuteCompromisedPasswords);

  // Add a muted password.
  PasswordForm form1 = MakeSavedPassword(kExampleCom, kUsername216);
  AddIssueToForm(&form1, InsecureType::kLeaked, base::Minutes(1), true);
  store().AddLogin(form1);
  RunUntilIdle();
  // Should return an empty list because the compromised credential is muted.
  EXPECT_THAT(manager().GetUnmutedCompromisedCredentials(), IsEmpty());

  // Add an unmuted password.
  PasswordForm form2 = MakeSavedPassword(kExampleCom, kUsername116);
  AddIssueToForm(&form2, InsecureType::kLeaked, base::Minutes(1), false);
  store().AddLogin(form2);
  RunUntilIdle();

  // Should return only the unmuted compromised credentials.
  EXPECT_THAT(manager().GetUnmutedCompromisedCredentials(),
              ElementsAre(CredentialUIEntry(form2)));
}
