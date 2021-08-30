# Copyright 2021 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
"""Test result related classes."""

from collections import OrderedDict
import shard_util
import time

from result_sink_util import ResultSinkClient

_VALID_RESULT_COLLECTION_INIT_KWARGS = set(['test_results', 'crashed'])
_VALID_TEST_RESULT_INIT_KWARGS = set(['expected_status', 'test_log'])
_VALID_TEST_STATUSES = set(['PASS', 'FAIL', 'CRASH', 'ABORT', 'SKIP'])


class TestStatus:
  """Enum storing possible test status(outcome).

  Confirms to ResultDB TestStatus definitions:
      https://source.chromium.org/chromium/infra/infra/+/main:go/src/go.chromium.org/luci/resultdb/proto/v1/test_result.proto
  """
  PASS = 'PASS'
  FAIL = 'FAIL'
  CRASH = 'CRASH'
  ABORT = 'ABORT'
  SKIP = 'SKIP'


def _validate_kwargs(kwargs, valid_args_set):
  """Validates if keywords in kwargs are accepted."""
  diff = set(kwargs.keys()) - valid_args_set
  assert len(diff) == 0, 'Invalid keyword argument(s) in %s passed in!' % diff


def _validate_test_status(status):
  """Raises if input isn't valid."""
  if not status in _VALID_TEST_STATUSES:
    raise TypeError('Invalid test status: %s. Should be one of %s.' %
                    (status, _VALID_TEST_STATUSES))


def _to_standard_json_literal(status):
  """Converts TestStatus literal to standard JSON format requirement.

  Standard JSON format defined at:
    https://source.chromium.org/chromium/infra/infra/+/main:go/src/go.chromium.org/luci/resultdb/proto/v1/test_result.proto

  ABORT is reported as "TIMEOUT" in standard JSON. The rest are the same.
  """
  _validate_test_status(status)
  return 'TIMEOUT' if status == TestStatus.ABORT else status


class TestResult(object):
  """Stores test outcome information of a single test run."""

  def __init__(self, name, status, **kwargs):
    """Initializes an object.

    Args:
      name: (str) Name of a test. Typically includes
      status: (str) Outcome of the test.
      (Following are possible arguments in **kwargs):
      expected_status: (str) Expected test outcome for the run.
      test_log: (str) Logs of the test.
    """
    _validate_kwargs(kwargs, _VALID_TEST_RESULT_INIT_KWARGS)
    self.name = name
    _validate_test_status(status)
    self.status = status

    self.expected_status = kwargs.get('expected_status', TestStatus.PASS)
    self.test_log = kwargs.get('test_log', '')

    # Use the var to avoid duplicate reporting.
    self._reported_to_result_sink = False

  def _compose_result_sink_tags(self):
    """Composes tags received by Result Sink from test result info."""
    # Only SKIP results have tags, to distinguish whether the SKIP is expected
    # (disabled test) or not.
    if self.status == TestStatus.SKIP:
      if self.disabled():
        return [('disabled_test', 'true')]
      return [('disabled_test', 'false')]
    return []

  def disabled(self):
    """Returns whether the result represents a disabled test."""
    return self.expected() and self.status == TestStatus.SKIP

  def expected(self):
    """Returns whether the result is expected."""
    return self.expected_status == self.status

  def report_to_result_sink(self, result_sink_client):
    """Reports the single result to result sink if never reported.

    Args:
      result_sink_client: (result_sink_util.ResultSinkClient) Result sink client
          to report test result.
    """
    if not self._reported_to_result_sink:
      result_sink_client.post(
          self.name,
          self.status,
          self.expected(),
          test_log=self.test_log,
          tags=self._compose_result_sink_tags())
      self._reported_to_result_sink = True


class ResultCollection(object):
  """Stores a collection of TestResult for one or more test app launches."""

  def __init__(self, **kwargs):
    """Initializes the object.

    Args:
      (Following are possible arguments in **kwargs):
      crashed: (bool) Whether the ResultCollection is of a crashed test launch.
      test_results: (list) A list of test_results to initialize the collection.
    """
    _validate_kwargs(kwargs, _VALID_RESULT_COLLECTION_INIT_KWARGS)
    self._test_results = []
    self._crashed = kwargs.get('crashed', False)
    self._crash_message = ''
    self.add_results(kwargs.get('test_results', []))

  @property
  def crashed(self):
    """Whether the invocation(s) of the collection is regarded as crashed.

    Crash indicates there might be tests unexpectedly not run that's not
    included in |_test_results| in the collection.
    """
    return self._crashed

  @crashed.setter
  def crashed(self, value):
    """Sets crash value."""
    assert (type(value) == bool)
    self._crashed = value

  @property
  def crash_message(self):
    """Logs from crashes in collection which are unrelated to single tests."""
    return self._crash_message

  @property
  def test_results(self):
    return self._test_results

  def add_test_result(self, test_result):
    """Adds a single test result to collection.

    Any new test addition should go through this method for all needed setups.
    """
    self._test_results.append(test_result)

  def add_result_collection(self,
                            another_collection,
                            ignore_crash=False,
                            overwrite_crash=False):
    """Adds results and status from another ResultCollection.

    Args:
      another_collection: (ResultCollection) The other collection to be added.
      ignore_crash: (bool) Ignore any crashes from newly added collection.
      overwrite_crash: (bool) Overwrite crash status of |self| and crash
          message. Only applicable when ignore_crash=False.
    """
    assert (not (ignore_crash and overwrite_crash))
    if not ignore_crash:
      if overwrite_crash:
        self._crashed = False
        self._crash_message = ''
      self._crashed = self.crashed or another_collection.crashed
      self.append_crash_message(another_collection.crash_message)
    for test_result in another_collection.test_results:
      self.add_test_result(test_result)

  def add_results(self, test_results):
    """Adds a list of |TestResult|."""
    for test_result in test_results:
      self.add_test_result(test_result)

  def add_name_prefix_to_tests(self, prefix):
    """Adds a prefix to all test names of results."""
    for test_result in self._test_results:
      test_result.name = '%s%s' % (prefix, test_result.name)

  def add_test_names_status(self, test_names, test_status, **kwargs):
    """Adds a list of test names with given test status.

    Args:
      test_names: (list) A list of names of tests to add.
      test_status: (str) The test outcome of the tests to add.
      **kwargs: See possible **kwargs in TestResult.__init__ docstring.
    """
    for test_name in test_names:
      self.add_test_result(TestResult(test_name, test_status, **kwargs))

  def append_crash_message(self, message):
    """Appends crash message str to current."""
    if self._crash_message:
      self._crash_message += '\n'
    self._crash_message += message

  def all_test_names(self):
    """Returns a set of all test names in collection."""
    return self.tests_by_expression(lambda result: True)

  def tests_by_expression(self, expression):
    """A set of test names by filtering test results with given |expression|.

    Args:
      expression: (TestResult -> bool) A function or lambda expression which
          accepts a TestResult object and returns bool.
    """
    return set(
        map(lambda result: result.name, filter(expression, self._test_results)))

  def crashed_tests(self):
    """A set of test names with any crashed status in the collection."""
    return self.tests_by_expression(lambda result: result.status == TestStatus.
                                    CRASH)

  def disabled_tests(self):
    """A set of disabled test names in the collection."""
    return self.tests_by_expression(lambda result: result.disabled())

  def expected_tests(self):
    """A set of test names with any expected status in the collection."""
    return self.tests_by_expression(lambda result: result.expected())

  def unexpected_tests(self):
    """A set of test names with any unexpected status in the collection."""
    return self.tests_by_expression(lambda result: not result.expected())

  def passed_tests(self):
    """A set of test names with any passed status in the collection."""
    return self.tests_by_expression(lambda result: result.status == TestStatus.
                                    PASS)

  def failed_tests(self):
    """A set of test names with any failed status in the collection."""
    return self.tests_by_expression(lambda result: result.status == TestStatus.
                                    FAIL)

  def flaky_tests(self):
    """A set of flaky test names in the collection."""
    return self.expected_tests().intersection(self.unexpected_tests())

  def never_expected_tests(self):
    """A set of test names with only unexpected status in the collection."""
    return self.unexpected_tests().difference(self.expected_tests())

  def pure_expected_tests(self):
    """A set of test names with only expected status in the collection."""
    return self.expected_tests().difference(self.unexpected_tests())

  def add_and_report_crash(self, crash_message_prefix_line=''):
    """Adds and reports a dummy failing test for crash.

    Typically called at the end of runner run when runner reports failure due to
    crash but there isn't unexpected tests.
    """
    self._crashed = True
    self._crash_message = crash_message_prefix_line + '\n' + self.crash_message
    crash_result = TestResult(
        "BUILD_INTERRUPTED", TestStatus.CRASH, test_log=self.crash_message)
    self.add_test_result(crash_result)
    result_sink_client = ResultSinkClient()
    crash_result.report_to_result_sink(result_sink_client)
    result_sink_client.close()

  def report_to_result_sink(self):
    """Reports current results to result sink once.

    Note that each |TestResult| object stores whether it's been reported and
    will only report itself once.
    """
    result_sink_client = ResultSinkClient()
    for test_result in self._test_results:
      test_result.report_to_result_sink(result_sink_client)
    result_sink_client.close()

  def standard_json_output(self, path_delimiter='.'):
    """Returns a dict object confirming to Chromium standard format.

    Format defined at:
      https://chromium.googlesource.com/chromium/src/+/main/docs/testing/json_test_results_format.md
    """
    num_failures_by_type = {}
    tests = OrderedDict()
    seen_names = set()
    shard_index = shard_util.shard_index()

    for test_result in self._test_results:
      test_name = test_result.name

      # For "num_failures_by_type" field. The field contains result count map of
      # the first result of each test.
      if test_name not in seen_names:
        seen_names.add(test_name)
        result_type = _to_standard_json_literal(test_result.status)
        num_failures_by_type[result_type] = num_failures_by_type.get(
            result_type, 0) + 1

      # For "tests" field.
      if test_name not in tests:
        tests[test_name] = {
            'expected': _to_standard_json_literal(test_result.expected_status),
            'actual': _to_standard_json_literal(test_result.status),
            'shard': shard_index,
            'is_unexpected': not test_result.expected()
        }
      else:
        tests[test_name]['actual'] += ' ' + _to_standard_json_literal(
            test_result.status)
        # This means there are both expected & unexpected results for the test.
        # Thus, the overall status would be expected (is_unexpected = False)
        # and the test is regarded flaky.
        if tests[test_name]['is_unexpected'] != (not test_result.expected()):
          tests[test_name]['is_unexpected'] = False
          tests[test_name]['is_flaky'] = True

    return {
        'version': 3,
        'path_delimiter': path_delimiter,
        'seconds_since_epoch': int(time.time()),
        'interrupted': self.crashed,
        'num_failures_by_type': num_failures_by_type,
        'tests': tests
    }

  def test_runner_logs(self):
    """Returns a dict object with test results as part of test runner logs."""
    # Test name to merged test log in all unexpected results. Logs are
    # only preserved for unexpected results.
    unexpected_logs = {}
    name_count = {}
    for test_result in self._test_results:
      if not test_result.expected():
        test_name = test_result.name
        name_count[test_name] = name_count.get(test_name, 0) + 1
        logs = unexpected_logs.get(test_name, [])
        logs.append('Failure log of attempt %d:' % name_count[test_name])
        logs.extend(test_result.test_log.split('\n'))
        unexpected_logs[test_name] = logs

    passed = list(self.passed_tests() & self.pure_expected_tests())
    disabled = list(self.disabled_tests())
    flaked = {
        test_name: unexpected_logs[test_name]
        for test_name in self.flaky_tests()
    }
    # "failed" in test runner logs are all unexpected failures (including
    # crash, etc).
    failed = {
        test_name: unexpected_logs[test_name]
        for test_name in self.never_expected_tests()
    }

    logs = OrderedDict()
    logs['passed tests'] = passed
    if disabled:
      logs['disabled tests'] = disabled
    if flaked:
      logs['flaked tests'] = flaked
    if failed:
      logs['failed tests'] = failed
    for test, log_lines in failed.iteritems():
      logs[test] = log_lines
    for test, log_lines in flaked.iteritems():
      logs[test] = log_lines

    return logs
