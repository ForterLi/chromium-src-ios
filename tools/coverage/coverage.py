#!/usr/bin/python
# Copyright 2017 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""Script to generate code coverage report for iOS.

  The generated code coverage report excludes test files, and test files are
  identified by postfixes: ['unittest.cc', 'unittest.mm', 'egtest.mm'].

  NOTE: This script must be called from the root of checkout. It may take up to
        a few minutes to generate a report for targets that depend on Chrome,
        such as ios_chrome_unittests. To simply play with this tool, you are
        suggested to start with 'url_unittests'.

  Example usages:
  ios/tools/coverage/coverage.py url_unittests -t url/ -i url/third_party
  # Generate code coverage report for url_unittests for directory url/ and only
  # include files under url/third_party.

  ios/tools/coverage/coverage.py url_unittests -t url/ -i url/third_party
  -r coverage.profdata
  # Skip running tests and reuse the specified profile data file.

  ios/tools/coverage/coverage.py url_unittests -t url/ -i url/third_party
  -e //url/ipc:url_ipc -r coverage.profdata
  # Exclude the 'sources' of //url/ipc:url_ipc build target.

  For more options, please refer to ios/tools/coverage/coverage.py -h
"""
import sys

import argparse
import ConfigParser
import json
import os
import subprocess

BUILD_DIRECTORY = 'out/Coverage-iphonesimulator'
DEFAULT_GOMA_JOBS = 50

# Name of the final profdata file, and this file needs to be passed to
# "llvm-cov" command in order to call "llvm-cov show" to inspect the
# line-by-line coverage of specific files.
PROFDATA_FILE_NAME = 'coverage.profdata'

# The code coverage profraw data file is generated by running the tests with
# coverage configuration, and the path to the file is part of the log that can
# be identified with the following identifier.
PROFRAW_LOG_IDENTIFIER = 'Coverage data at '

# Only test targets with the following postfixes are considered to be valid.
VALID_TEST_TARGET_POSTFIXES = ['unittests', 'inttests', 'egtests']

# Used to determine if a test target is an earl grey test.
EARL_GREY_TEST_TARGET_POSTFIX = 'egtests'

# Used to determine if a file is a test file. The coverage of test files should
# be excluded from code coverage report.
# TODO(crbug.com/763957): Make test file identifiers configurable.
TEST_FILES_POSTFIXES = ['unittest.mm', 'unittest.cc', 'egtest.mm']


class _FileLineCoverageReport(object):
  """Encapsulates coverage calculations for files."""

  def __init__(self):
    """Initializes FileLineCoverageReport object."""
    self._coverage = {}

  def AddFile(self, path, total_lines, executed_lines):
    """Adds a new file entry.

    Args:
      path: path to the file.
      total_lines: Total number of lines.
      executed_lines: Total number of executed lines.
    """
    summary = {
        'total': total_lines,
        'executed': executed_lines
    }
    self._coverage[path] = summary

  def ContainsFile(self, path):
    """Returns True if the path is in the report.

    Args:
      path: path to the file.

    Returns:
      True if the path is in the report.
    """
    return path in self._coverage

  def GetCoverageForFile(self, path):
    """Returns tuple representing coverage for a file.

    Args:
      path: path to the file.

    Returns:
      tuple with two integers (total number of lines, number of executed lines.)
    """
    assert path in self._coverage, '{} is not in the report.'.format(path)
    return self._coverage[path]['total'], self._coverage[path]['executed']

  def GetListOfFiles(self):
    """Returns a list of files in the report.

    Returns:
      A list of files.
    """
    return self._coverage.keys()

  def FilterFiles(self, include_sources, exclude_sources):
    """Filter files in the report.

    Only includes files that is under at least one of the paths in
    |include_sources|, but none of them in |exclude_sources|.

    Args:
      include_sources: A list of directories and files.
      exclude_sources: A list of directories and files.
    """
    files_to_delete = []
    for path in self._coverage:
      should_include = (any(path.startswith(source)
                            for source in include_sources))
      should_exclude = (any(path.startswith(source)
                            for source in exclude_sources))

      if not should_include or should_exclude:
        files_to_delete.append(path)

    for path in files_to_delete:
      del self._coverage[path]

  def ExcludeTestFiles(self):
    """Exclude test files from the report.

    Test files are identified by |TEST_FILES_POSTFIXES|.
    """
    files_to_delete = []
    for path in self._coverage:
      if any(path.endswith(postfix) for postfix in TEST_FILES_POSTFIXES):
        files_to_delete.append(path)

    for path in files_to_delete:
      del self._coverage[path]


class _DirectoryLineCoverageReport(object):
  """Encapsulates coverage calculations for directories."""

  def __init__(self, file_line_coverage_report, top_level_dir):
    """Initializes DirectoryLineCoverageReport object."""
    self._coverage = {}
    self._CalculateCoverageForDirectory(top_level_dir, self._coverage,
                                        file_line_coverage_report)

  def _CalculateCoverageForDirectory(self, path, line_coverage_result,
                                     file_line_coverage_report):
    """Recursively calculate the line coverage for a directory.

    Args:
      path: path to the directory.
      line_coverage_result: per directory line coverage result with format:
                            dict => A dictionary containing line coverage data.
                            -- dir_path: dict => Line coverage summary.
                            ---- total: int => total number of lines.
                            ---- executed: int => executed number of lines.
      file_line_coverage_report: a FileLineCoverageReport object.
    """
    if path in line_coverage_result:
      return

    sum_total_lines = 0
    sum_executed_lines = 0
    for sub_name in os.listdir(path):
      sub_path = os.path.join(path, sub_name)
      if os.path.isdir(sub_path):
        # Calculate coverage for sub-directories recursively.
        self._CalculateCoverageForDirectory(sub_path, line_coverage_result,
                                            file_line_coverage_report)

      if os.path.isdir(sub_path):
        sum_total_lines += line_coverage_result[sub_path]['total']
        sum_executed_lines += line_coverage_result[sub_path]['executed']
      elif file_line_coverage_report.ContainsFile(sub_path):
        total_lines, executed_lines = (
            file_line_coverage_report.GetCoverageForFile(sub_path))
        sum_total_lines += total_lines
        sum_executed_lines += executed_lines

    line_coverage_result[path] = {'total': sum_total_lines,
                                  'executed': sum_executed_lines}

  def GetCoverageForDirectory(self, path):
    """Returns tuple representing coverage for a directory.

    Args:
      path: path to the directory.

    Returns:
      tuple with two integers (total number of lines, number of executed lines.)
    """
    assert path in self._coverage, '{} is not in the report.'.format(path)
    return self._coverage[path]['total'], self._coverage[path]['executed']


def _CreateCoverageProfileDataForTarget(target, jobs_count=None,
                                        gtest_filter=None):
  """Builds and runs target to generate the coverage profile data.

  Args:
    target: A string representing the name of the target to be tested.
    jobs_count: Number of jobs to run in parallel for building. If None, a
                default value is derived based on CPUs availability.
    gtest_filter: If present, only run unit tests whose full name matches the
                  filter.

  Returns:
    A string representing the absolute path to the generated profdata file.
  """
  _BuildTargetWithCoverageConfiguration(target, jobs_count)
  profraw_path = _GetProfileRawDataPathByRunningTarget(target, gtest_filter)
  profdata_path = _CreateCoverageProfileDataFromProfRawData(profraw_path)

  print 'Code coverage profile data is created as: ' + profdata_path
  return profdata_path


def _GeneratePerFileLineCoverageReport(target, profdata_path):
  """Generate per file code coverage report using llvm-cov report.

  The officially suggested command to export code coverage data is to use
  "llvm-cov export", which returns comprehensive code coverage data in a json
  object, however, due to the large size and complicated dependencies of
  Chrome, "llvm-cov export" takes too long to run, and for example, it takes 5
  minutes for ios_chrome_unittests. Therefore, this script gets code coverage
  data by calling "llvm-cov report", which is significantly faster and provides
  the same data.

  The raw code coverage report returned from "llvm-cov report" has the following
  format:
  Filename\tRegions\tMissed Regions\tCover\tFunctions\tMissed Functions\t
  Executed\tInstantiations\tMissed Insts.\tLines\tMissed Lines\tCover
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  base/at_exit.cc\t89\t85\t4.49%\t7\t6\t14.29%\t7\t6\t14.29%\t107\t99\t7.48%
  url/pathurl.cc\t89\t85\t4.49%\t7\t6\t14.29%\t7\t6\t14.29%\t107\t99\t7.48%
  ------------------------------------------------------------------------------
  ------------------------------------------------------------------------------
  In Total\t89\t85\t4.49%\t7\t6\t14.29%\t7\t6\t14.29%\t107\t99\t7.48%

  Args:
    target: A string representing the name of the target to be tested.
    profdata_path: A string representing the path to the profdata file.

  Returns:
    A FileLineCoverageReport object.
  """
  application_path = _GetApplicationBundlePath(target)
  binary_path = os.path.join(application_path, target)
  cmd = ['xcrun', 'llvm-cov', 'report', '-instr-profile', profdata_path,
         '-arch=x86_64', binary_path]
  std_out = subprocess.check_output(cmd)
  std_out_by_lines = std_out.split('\n')

  # Strip out the unrelated lines. The 1st line is the header and the 2nd line
  # is a '-' separator line. The last line is an empty line break, the second
  # to last line is the in total coverage and the third to last line is a '-'
  # separator line.
  coverage_content_by_files = std_out_by_lines[2: -3]

  # The 3rd to last column contains the total number of lines.
  total_lines_index = -3

  # The 2nd to last column contains the missed number of lines.
  missed_lines_index = -2

  file_line_coverage_report = _FileLineCoverageReport()
  for coverage_content in coverage_content_by_files:
    coverage_data = coverage_content.split()
    file_name = coverage_data[0]

    # TODO(crbug.com/765818): llvm-cov has a bug that proceduces invalid data in
    # the report, and the following hack works it around. Remove the hack once
    # the bug is fixed.
    try:
      total_lines = int(coverage_data[total_lines_index])
      missed_lines = int(coverage_data[missed_lines_index])
    except ValueError:
      continue

    executed_lines = total_lines - missed_lines
    file_line_coverage_report.AddFile(file_name, total_lines, executed_lines)

  return file_line_coverage_report


def _PrintLineCoverageStats(total, executed):
  """Print line coverage statistics.

  The format is as following:
    Total Lines: 20 Executed Lines: 2 Missed lines: 18 Coverage: 10%

  Args:
    total: total number of lines.
    executed: number of lines that are executed.
  """
  missed = total - executed
  coverage = float(executed) / total if total > 0 else None
  percentage_coverage = ('{}%'.format(int(coverage * 100))
                         if coverage is not None else 'NA')

  output = ('Total Lines: {}\tExecuted Lines: {}\tMissed Lines: {}\t'
            'Coverage: {}\n')
  print output.format(total, executed, missed, percentage_coverage)


def _BuildTargetWithCoverageConfiguration(target, jobs_count):
  """Builds target with coverage configuration.

  This function requires current working directory to be the root of checkout.

  Args:
    target: A string representing the name of the target to be tested.
    jobs_count: Number of jobs to run in parallel for compilation. If None, a
                default value is derived based on CPUs availability.
  """
  print 'Building ' + target

  src_root = _GetSrcRootPath()
  build_dir_path = os.path.join(src_root, BUILD_DIRECTORY)

  cmd = ['ninja', '-C', build_dir_path]
  if jobs_count:
    cmd.append('-j' + str(jobs_count))

  cmd.append(target)
  subprocess.check_call(cmd)


def _GetProfileRawDataPathByRunningTarget(target, gtest_filter=None):
  """Runs target and returns the path to the generated profraw data file.

  The output log of running the test target has no format, but it is guaranteed
  to have a single line containing the path to the generated profraw data file.

  Args:
    target: A string representing the name of the target to be tested.
    gtest_filter: If present, only run unit tests whose full name matches the
                  filter.

  Returns:
    A string representing the absolute path to the generated profraw data file.
  """
  logs = _RunTestTargetWithCoverageConfiguration(target, gtest_filter)
  for log in logs:
    if PROFRAW_LOG_IDENTIFIER in log:
      profraw_path = log.split(PROFRAW_LOG_IDENTIFIER)[1][:-1]
      return os.path.abspath(profraw_path)

  assert False, ('No profraw data file is generated, did you call '
                 'coverage_util::ConfigureCoverageReportPath() in test setup? '
                 'Please refer to base/test/test_support_ios.mm for example.')


def _RunTestTargetWithCoverageConfiguration(target, gtest_filter=None):
  """Runs tests to generate the profraw data file.

  This function requires current working directory to be the root of checkout.

  Args:
    target: A string representing the name of the target to be tested.
    gtest_filter: If present, only run unit tests whose full name matches the
                  filter.

  Returns:
    A list of lines/strings created from the output log by breaking lines. The
    log has no format, but it is guaranteed to have a single line containing the
    path to the generated profraw data file.
  """
  iossim_path = _GetIOSSimPath()
  application_path = _GetApplicationBundlePath(target)

  cmd = [iossim_path]

  # For iossim arguments, please refer to src/testing/iossim/iossim.mm.
  if gtest_filter:
    cmd.append('-c --gtest_filter=' + gtest_filter)

  cmd.append(application_path)
  if _TargetIsEarlGreyTest(target):
    cmd.append(_GetXCTestBundlePath(target))

  print 'Running {} with command: {}'.format(target, ' '.join(cmd))

  logs_chracters = subprocess.check_output(cmd)

  return ''.join(logs_chracters).split('\n')


def _CreateCoverageProfileDataFromProfRawData(profraw_path):
  """Returns the path to the profdata file by merging profraw data file.

  Args:
    profraw_path: A string representing the absolute path to the profraw data
                  file that is to be merged.

  Returns:
    A string representing the absolute path to the generated profdata file.

  Raises:
    CalledProcessError: An error occurred merging profraw data files.
  """
  print 'Creating the profile data file'

  src_root = _GetSrcRootPath()
  profdata_path = os.path.join(src_root, BUILD_DIRECTORY,
                               PROFDATA_FILE_NAME)
  try:
    cmd = ['xcrun', 'llvm-profdata', 'merge', '-o', profdata_path, profraw_path]
    subprocess.check_call(cmd)
  except subprocess.CalledProcessError as error:
    print 'Failed to merge profraw to create profdata.'
    raise error

  return profdata_path


def _GetSrcRootPath():
  """Returns the absolute path to the root of checkout.

  Returns:
    A string representing the absolute path to the root of checkout.
  """
  return os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir,
                                      os.pardir, os.pardir))


def _GetApplicationBundlePath(target):
  """Returns the path to the generated application bundle after building.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A string representing the path to the generated application bundle.
  """
  src_root = _GetSrcRootPath()
  application_bundle_name = target + '.app'
  return os.path.join(src_root, BUILD_DIRECTORY, application_bundle_name)


def _GetXCTestBundlePath(target):
  """Returns the path to the xctest bundle after building.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A string representing the path to the generated xctest bundle.
  """
  application_path = _GetApplicationBundlePath(target)
  xctest_bundle_name = target + '_module.xctest'
  return os.path.join(application_path, 'PlugIns', xctest_bundle_name)


def _GetIOSSimPath():
  """Returns the path to the iossim executable file after building.

  Returns:
    A string representing the path to the iossim executable file.
  """
  src_root = _GetSrcRootPath()
  iossim_path = os.path.join(src_root, BUILD_DIRECTORY, 'iossim')
  return iossim_path


def _IsGomaConfigured():
  """Returns True if goma is enabled in the gn build settings.

  Returns:
    A boolean indicates whether goma is configured for building or not.
  """
  # Load configuration.
  settings = ConfigParser.SafeConfigParser()
  settings.read(os.path.expanduser('~/.setup-gn'))
  return settings.getboolean('goma', 'enabled')


def _TargetIsEarlGreyTest(target):
  """Returns true if the target is an earl grey test.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A boolean indicates whether the target is an earl grey test or not.
  """
  return target.endswith(EARL_GREY_TEST_TARGET_POSTFIX)


def _TargetNameIsValidTestTarget(target):
  """Returns True if the target name has a valid postfix.

  The list of valid target name postfixes are defined in
  VALID_TEST_TARGET_POSTFIXES.

  Args:
    target: A string representing the name of the target to be tested.

  Returns:
    A boolean indicates whether the target is a valid test target.
  """
  return (any(target.endswith(postfix) for postfix in
              VALID_TEST_TARGET_POSTFIXES))


def _AssertCoverageBuildDirectoryExists():
  """Asserts that the build directory with converage configuration exists."""
  src_root = _GetSrcRootPath()
  build_dir_path = os.path.join(src_root, BUILD_DIRECTORY)
  assert os.path.exists(build_dir_path), (build_dir_path + " doesn't exist."
                                          'Hint: run gclient runhooks or '
                                          'ios/build/tools/setup-gn.py.')


def _SeparatePathsAndBuildTargets(paths_or_build_targets):
  """Separate file/directory paths from build target paths.

  Args:
    paths_or_build_targets: A list of file/directory or build target paths.

  Returns:
    Two lists contain the file/directory and build target paths respectively.
  """
  paths = []
  build_targets = []
  for path_or_build_target in paths_or_build_targets:
    if path_or_build_target.startswith('//'):
      build_targets.append(path_or_build_target)
    else:
      paths.append(path_or_build_target)

  return paths, build_targets


def _FormatBuildTargetPaths(build_targets):
  """Formats build target paths to explicitly specify target name.

  Build target paths may have target name omitted, this method adds a target
  name for the path if it is.
  For example, //url is converted to //url:url.

  Args:
    build_targets: A list of build targets.

  Returns:
    A list of build targets.
  """
  formatted_build_targets = []
  for build_target in build_targets:
    if ':' not in os.path.basename(build_target):
      formatted_build_targets.append(
          build_target + ':' + os.path.basename(build_target))
    else:
      formatted_build_targets.append(build_target)

  return formatted_build_targets


def _AssertBuildTargetsExist(build_targets):
  """Asserts that the build targets specified in |build_targets| exist.

  Args:
    build_targets: A list of build targets.
  """
  # The returned json objec has the following format:
  # Root: dict => A dictionary of sources of build targets.
  # -- target: dict => A dictionary that describes the target.
  # ---- sources: list => A list of source files.
  #
  # For example:
  # {u'//url:url': {u'sources': [u'//url/gurl.cc', u'//url/url_canon_icu.cc']}}
  #
  target_source_descriptions = _GetSourcesDescriptionOfBuildTargets(
      build_targets)
  for build_target in build_targets:
    assert build_target in target_source_descriptions, (('{} is not a valid '
                                                         'build target. Please '
                                                         'run \'gn desc {} '
                                                         'sources\' to debug.')
                                                        .format(build_target,
                                                                build_target))


def _AssertPathsExist(paths):
  """Asserts that the paths specified in |paths| exist.

  Args:
    paths: A list of files or directories.
  """
  src_root = _GetSrcRootPath()
  for path in paths:
    abspath = os.path.join(src_root, path)
    assert os.path.exists(abspath), (('Path: {} doesn\'t exist.\nA valid '
                                      'path must exist and be relative to the '
                                      'root of source, which is {}. For '
                                      'example, \'ios/\' is a valid path.').
                                     format(abspath, src_root))


def _GetSourcesOfBuildTargets(build_targets):
  """Returns a list of paths corresponding to the sources of the build targets.

  Args:
    build_targets: A list of build targets.

  Returns:
    A list of os paths relative to the root of checkout, and en empty list if
    |build_targets| is empty.
  """
  if not build_targets:
    return []

  target_sources_description = _GetSourcesDescriptionOfBuildTargets(
      build_targets)
  sources = []
  for build_target in build_targets:
    sources.extend(_ConvertBuildFilePathsToOsPaths(
        target_sources_description[build_target]['sources']))

  return sources


def _GetSourcesDescriptionOfBuildTargets(build_targets):
  """Returns the description of sources of the build targets using 'gn desc'.

  Args:
    build_targets: A list of build targets.

  Returns:
    A json object with the following format:

    Root: dict => A dictionary of sources of build targets.
    -- target: dict => A dictionary that describes the target.
    ---- sources: list => A list of source files.
  """
  cmd = ['gn', 'desc', BUILD_DIRECTORY]
  for build_target in build_targets:
    cmd.append(build_target)
  cmd.extend(['sources', '--format=json'])

  return json.loads(subprocess.check_output(cmd))


def _ConvertBuildFilePathsToOsPaths(build_file_paths):
  """Converts paths in build file format to os path format.

  Args:
    build_file_paths: A list of paths starts with '//'.

  Returns:
   A list of os paths relative to the root of checkout.
  """
  return [build_file_path[2:] for build_file_path in build_file_paths]


def _ParseCommandArguments():
  """Add and parse relevant arguments for tool commands.

  Returns:
    A dictionanry representing the arguments.
  """
  arg_parser = argparse.ArgumentParser()
  arg_parser.usage = __doc__

  arg_parser.add_argument('-t', '--top-level-dir', type=str, required=True,
                          help='The top level directory to show code coverage '
                               'report, the path needs to be relative to the '
                               'root of the checkout.')

  arg_parser.add_argument('-i', '--include', action='append', required=True,
                          help='Directories or build targets to get code '
                               'coverage for. For directories, paths need to '
                               'be relative to the root of the checkoutand and '
                               'all files under them are included recursively; '
                               'for build targets, only the \'sources\' of the '
                               'targets are included, and the format of '
                               'specifying build targets is the same as in '
                               '\'deps\' in BUILD.gn.')

  arg_parser.add_argument('-e', '--exclude', action='append',
                          help='Directories or build targets to get code '
                               'coverage for. For directories, paths need to '
                               'be relative to the root of the checkoutand and '
                               'all files under them are excluded recursively; '
                               'for build targets, only the \'sources\' of the '
                               'targets are excluded, and the format of '
                               'specifying build targets is the same as in '
                               '\'deps\' in BUILD.gn.')

  arg_parser.add_argument('-j', '--jobs', type=int, default=None,
                          help='Run N jobs to build in parallel. If not '
                               'specified, a default value will be derived '
                               'based on CPUs availability. Please refer to '
                               '\'ninja -h\' for more details.')

  arg_parser.add_argument('-r', '--reuse-profdata', type=str,
                          help='Skip building test target and running tests '
                               'and re-use the specified profile data file.')

  arg_parser.add_argument('--gtest_filter', type=str,
                          help='Only run unit tests whose full name matches '
                               'the filter.')

  arg_parser.add_argument('target', nargs='+',
                          help='The name of the test target to run.')

  args = arg_parser.parse_args()
  return args


def Main():
  """Executes tool commands."""
  args = _ParseCommandArguments()
  targets = args.target
  assert len(targets) == 1, ('targets: ' + str(targets) + ' are detected, '
                             'however, only a single target is supported now.')

  target = targets[0]
  if not _TargetNameIsValidTestTarget(target):
    assert False, ('target: ' + str(target) + ' is detected, however, only '
                   'target name with the following postfixes are supported: ' +
                   str(VALID_TEST_TARGET_POSTFIXES))

  jobs = args.jobs
  if not jobs and _IsGomaConfigured():
    jobs = DEFAULT_GOMA_JOBS

  print 'Validating inputs'
  _AssertCoverageBuildDirectoryExists()
  _AssertPathsExist([args.top_level_dir])

  include_paths, raw_include_targets = _SeparatePathsAndBuildTargets(
      args.include)
  exclude_paths, raw_exclude_targets = _SeparatePathsAndBuildTargets(
      args.exclude or [])
  include_targets = _FormatBuildTargetPaths(raw_include_targets)
  exclude_targets = _FormatBuildTargetPaths(raw_exclude_targets)

  if include_paths:
    _AssertPathsExist(include_paths)
  if exclude_paths:
    _AssertPathsExist(exclude_paths)
  if include_targets:
    _AssertBuildTargetsExist(include_targets)
  if exclude_targets:
    _AssertBuildTargetsExist(exclude_targets)

  include_sources = include_paths + _GetSourcesOfBuildTargets(include_targets)
  exclude_sources = exclude_paths + _GetSourcesOfBuildTargets(exclude_targets)

  profdata_path = args.reuse_profdata
  if profdata_path:
    assert os.path.exists(profdata_path), ('The provided profile data file: {} '
                                           'doesn\'t exist.').format(
                                               profdata_path)
  else:
    profdata_path = _CreateCoverageProfileDataForTarget(target, jobs,
                                                        args.gtest_filter)

  print 'Generating code coverge report'
  file_line_coverage_report = _GeneratePerFileLineCoverageReport(
      target, profdata_path)
  file_line_coverage_report.FilterFiles(include_sources, exclude_sources)
  file_line_coverage_report.ExcludeTestFiles()

  # ios/chrome and ios/chrome/ refer to the same directory.
  top_level_dir = os.path.normpath(args.top_level_dir)

  dir_line_coverage_report = _DirectoryLineCoverageReport(
      file_line_coverage_report, top_level_dir)

  print '\nLine Coverage Report for: ' + top_level_dir
  total, executed = dir_line_coverage_report.GetCoverageForDirectory(
      top_level_dir)
  _PrintLineCoverageStats(total, executed)


if __name__ == '__main__':
  sys.exit(Main())
