# frozen_string_literal: true

require "test_helper"

module ActionMCP
  class UriAmbiguityCheckerTest < ActiveSupport::TestCase
    test "are_potentially_ambiguous?" do
      # This could be a good candidate for a data-driven test and add more test cases, but for now, it works for my case
      test_cases = [
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://users/{user_id}/profile",      expected: true },
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://users/{id}/{something_id}",    expected: true },
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://users/{type}/profile",         expected: true },
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://posts/{id}/profile",           expected: false },
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://users/{id}/comments",          expected: false },
        { pattern1: "fetch://users/{id}",              pattern2: "fetch://users/{id}",                   expected: true },
        { pattern1: "fetch://users/{id}",              pattern2: "fetch://users/123",                    expected: true },
        { pattern1: "fetch://users/{id}/profile",      pattern2: "fetch://users/{id}",                   expected: false },
        { pattern1: "fetch://users/{id}",              pattern2: "fetch://users/{id}/profile",           expected: false },
        { pattern1: "fetch://{org}/{repo}/issues/{number}", pattern2: "fetch://{owner}/{project}/pulls/{pull_number}", expected: false },
        { pattern1: "service://users/{id}/profile",    pattern2: "service://users/{user_id}/profile",    expected: true },
        { pattern1: "service://users/{id}/profile",    pattern2: "service://{type}/users/profile",       expected: true },
        { pattern1: "service://users/{id}",            pattern2: "service://users/123",                  expected: true },
        { pattern1: "service://users/{id}",            pattern2: "details://users/{id}",                 expected: false },
        { pattern1: "service://a/b/c",                 pattern2: "service://x/y/z",                      expected: false },
        { pattern1: "service://a/{b}/c",               pattern2: "service://x/{y}/z",                    expected: false },
        { pattern1: "service://a/{b}/c",               pattern2: "service://a/b/c",                      expected: false },
        { pattern1: "service://a/b/c",                 pattern2: "service://a/{b}/c",                    expected: false },
        { pattern1: "service://{a}/{b}/{c}",           pattern2: "service://1/2/3",                      expected: true },
        { pattern1: "service://{a}/{b}/{c}",           pattern2: "service://1/2/{c}",                    expected: true },
        { pattern1: "service://{a}/{b}/{c}",           pattern2: "service://{a}/2/3",                    expected: true },
        { pattern1: "fetch://api/v1/{resource}",       pattern2: "fetch://api/v1/users",                 expected: true },
        { pattern1: "fetch://api/v1/{resource}",       pattern2: "fetch://api/v2/{resource}",            expected: false },
        { pattern1: "fetch://blog/{year}/{month}/{slug}", pattern2: "fetch://blog/{year}/{month}/{id}",      expected: true },
        { pattern1: "fetch://blog/{year}/{month}/{slug}", pattern2: "fetch://blog/archive/{year}/{month}",    expected: true },
        { pattern1: "fetch://products/{category}/{id}",  pattern2: "fetch://products/{category}/list",     expected: true },
        { pattern1: "fetch://products/{category}/list",  pattern2: "fetch://products/{category}/view",     expected: false },
        { pattern1: "fetch://account/{action}",          pattern2: "fetch://account/settings",             expected: true },
        { pattern1: "fetch://files/{folder}/{file}",       pattern2: "fetch://files/public/{file}",            expected: true },
        { pattern1: "fetch://files/{folder}/{file}",       pattern2: "fetch://files/private/{file}",           expected: true },
        { pattern1: "fetch://search/{query}",              pattern2: "fetch://search/advanced",              expected: true }
      ]


        class TestClass < ActionMCP::ResourceTemplate
          include UriAmbiguityChecker
        end

        test_cases.each do |test_case|
          pattern1 = test_case[:pattern1]
          pattern2 = test_case[:pattern2]
          expected = test_case[:expected]
          assert_equal expected, TestClass.are_potentially_ambiguous?(pattern1, pattern2),
                       "\#{pattern1} vs \#{pattern2}"
        end
      end
  end
end
