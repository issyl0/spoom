# typed: true
# frozen_string_literal: true

require "test_helper"

module Spoom
  module Cli
    class BumpTest < Minitest::Test
      include Spoom::TestHelper

      def setup
        @project = spoom_project
      end

      def teardown
        @project.destroy
      end

      def test_bump_outside_sorbet_dir
        @project.remove("sorbet/config")
        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.out)
        assert_equal("Error: not in a Sorbet project (`sorbet/config` not found)", result.err.lines.first.chomp)
        refute(result.status)
      end

      def test_bump_no_file
        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `false` to `true`
        OUT
        assert(result.status)
      end

      def test_bump_files_one_error_no_bump_one_no_error_bump
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: false
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `false` to `true`:
           + file1.rb
        OUT
        refute(result.status)

        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_doesnt_change_sigils_outside_directory
        @project.write("lib/a/file.rb", "# typed: false")
        @project.write("lib/b/file.rb", "# typed: false")
        @project.write("lib/c/file.rb", "# typed: true\n\nfoo.bar")

        result = @project.bundle_exec("spoom bump --no-color lib/b")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `false` to `true`:
           + lib/b/file.rb
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/lib/a/file.rb"))
        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/lib/b/file.rb"))
        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/lib/c/file.rb"))

        @project.destroy
      end

      def test_bump_nondefault_from_to_complete
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: true
          class B; end
        RB

        result = @project.bundle_exec("spoom bump --no-color --from true --to strict")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `true` to `strict`:
           + file2.rb
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("strict", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_nondefault_from_to_revert
        @project.write("file1.rb", <<~RB)
          # typed: ignore
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: ignore
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color --from ignore --to strong")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `ignore` to `strong`:
           + file1.rb
        OUT
        refute(result.status)

        assert_equal("strong", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("ignore", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_force_bump_without_typecheck
        @project.write("file1.rb", <<~RB)
          # typed: ignore
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: ignore
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color --force --from ignore --to strong")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `2` files from `ignore` to `strong`:
           + file1.rb
           + file2.rb
        OUT
        refute(result.status)

        assert_equal("strong", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("strong", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_with_multiline_error
        @project.write("file.rb", <<~RB)
          # typed: true
          require "test_helper"

          class Test
            def self.foo(*arg); end
            def self.something; end
            def self.something_else; end

            foo "foo" do
              q = something do
                q = something_else.new
              end
            end
          end
        RB

        result = @project.bundle_exec("spoom bump --no-color --from true --to strict")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `true` to `strict`
        OUT
        assert(result.status)

        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/file.rb"))
      end

      def test_bump_with_custom_error_url_base
        @project.sorbet_config(<<~CONFIG)
          .
          --error-url-base="https://docs.org#"
        CONFIG

        @project.write("file.rb", <<~RB)
          # typed: true
          require "test_helper"

          class Test
            def self.foo(*arg); end
            def self.something; end
            def self.something_else; end

            foo "foo" do
              q = something do
                q = something_else.new
              end
            end
          end
        RB

        result = @project.bundle_exec("spoom bump --no-color --from true --to strict")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `true` to `strict`
        OUT
        assert(result.status)

        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/file.rb"))
      end

      def test_bump_preserve_file_encoding
        string = <<~RB
          # typed: false
          puts "À coûté 10€"
        RB

        @project.write("file.rb", string.encode("ISO-8859-15"))
        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `false` to `true`:
           + file.rb
        OUT
        refute(result.status)

        strictness = Sorbet::Sigils.file_strictness("#{@project.path}/file.rb")
        assert_equal("true", strictness)
        assert_match("ISO-8859", %x{file "#{@project.path}/file.rb"})
      end

      def test_bump_dry_does_nothing
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: false
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color --dry")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Can bump `1` file from `false` to `true`:
           + file1.rb

          Run `spoom bump --from false --to true` locally then `commit the changes` and `push them`
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_dry_does_nothing_even_with_force
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB
        @project.write("file2.rb", <<~RB)
          # typed: false
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color --dry -f")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Can bump `2` files from `false` to `true`:
           + file1.rb
           + file2.rb

          Run `spoom bump --from false --to true` locally then `commit the changes` and `push them`
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_dry_suggest_custom_command
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB

        result = @project.bundle_exec("spoom bump --no-color --dry -f --suggest-bump-command 'bump.sh'")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Can bump `1` file from `false` to `true`:
           + file1.rb

          Run `bump.sh` to bump them
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
      end

      def test_bump_dry_does_nothing_with_no_file
        result = @project.bundle_exec("spoom bump --no-color --dry")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `false` to `true`
        OUT
        assert(result.status)
      end

      def test_bump_dry_does_nothing_with_no_bumpable_file
        @project.write("file1.rb", <<~RB)
          # typed: false
          T.reveal_type(1)
        RB
        @project.write("file2.rb", <<~RB)
          # typed: false
          T.reveal_type(1)
        RB

        result = @project.bundle_exec("spoom bump --no-color --dry")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `false` to `true`
        OUT
        assert(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rb"))
      end

      def test_bump_dry_does_not_revert_files_not_bumped
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A
            def bar(a, b); end
          end
        RB
        @project.write("file2.rbi", <<~RB)
          # typed: true
          class A
            CONSTANT_NOT_FOUND # we want there to be an existing type error in this file
            def foo(a, b, c); end
          end
        RB

        result = @project.bundle_exec("spoom bump --no-color --from false --to true --dry")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Can bump `1` file from `false` to `true`:
           + file1.rb

          Run `spoom bump --from false --to true` locally then `commit the changes` and `push them`
        OUT
        refute(result.status)

        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/file2.rbi"))
      end

      def test_bump_only_specified_files
        @project.write("file1.rb", "# typed: false")
        @project.write("file2.rb", "# typed: false")
        @project.write("file3.rb", "# typed: false")
        @project.write("file4.rb", "# typed: false")
        @project.write("file5.rb", "# typed: false")
        @project.write("files.lst", <<~FILES)
          file1.rb
          file3.rb
          file5.rb
        FILES

        result = @project.bundle_exec("spoom bump --no-color -o files.lst")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `3` files from `false` to `true`:
           + file1.rb
           + file3.rb
           + file5.rb
        OUT
        refute(result.status)
      end

      def test_bump_files_according_to_config
        @project.sorbet_config(<<~CONFIG)
          .
          --ignore=vendor/
        CONFIG
        @project.write("file1.rb", <<~RB)
          # typed: false
          class A; end
        RB
        @project.write("vendor/file2.rb", <<~RB)
          # typed: false
          class A; end
        RB

        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `false` to `true`:
           + file1.rb
        OUT
        refute(result.status)

        assert_equal("true", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/vendor/file2.rb"))
      end

      def test_count_errors_without_dry
        @project.write("file1.rb", <<~RB)
          # typed: false
          class Foo
            def foo
            end
          end

          Foo.new.foos
        RB

        result = @project.bundle_exec("spoom bump --no-color --count-errors")
        assert_empty(result.out)
        assert_equal(<<~OUT, result.err)
          Error: `--count-errors` can only be used with `--dry`
        OUT
        refute(result.status)
      end

      def test_bump_count_errors
        @project.write("file1.rb", <<~RB)
          # typed: false
          class Foo
            def foo
            end
          end

          Foo.new.foos
        RB

        result = @project.bundle_exec("spoom bump --no-color --count-errors --dry")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Found 1 type checking error
          No file to bump from `false` to `true`
        OUT
        assert(result.status)
        assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/file1.rb"))
      end

      def test_bump_with_sorbet_segfault
        @project.gemfile(<<~GEMFILE)
          source "https://rubygems.org"

          gem "sorbet-static", "= 0.5.9267"
          gem "spoom", path: "#{Spoom::SPOOM_PATH}"
        GEMFILE
        @project.write("cant_be_bump1.rb", <<~RB)
          # typed: false
          foo
        RB
        @project.write("cant_be_bump2.rb", <<~RB)
          # typed: false
          bar
        RB
        @project.write("will_segfault.rb", <<~RB)
          # typed: false
          [{1 => 2}] + [{}]
        RB
        Bundler.with_unbundled_env do
          result = @project.bundle_install
          assert(result.status)

          result = @project.bundle_exec("spoom bump --no-color")
          assert_equal(<<~OUT, result.err)
            !!! Sorbet exited with code 139 - SEGFAULT !!!

            This is most likely related to a bug in Sorbet.
            It means one of the file bumped to `typed: true` made Sorbet crash.
            Run `spoom bump -f` locally followed by `bundle exec srb tc` to investigate the problem.
          OUT
          refute(result.status)

          assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/cant_be_bump1.rb"))
          assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/cant_be_bump2.rb"))
          assert_equal("false", Sorbet::Sigils.file_strictness("#{@project.path}/will_segfault.rb"))
        end
      end

      def test_bump_display_sorbet_error
        @project.write("file.rb", <<~RB)
          # typed: false
        RB
        result = @project.bundle_exec("spoom bump --no-color --sorbet-options=\"--not-found\"")
        assert_equal(<<~MSG, result.err)
          Option ‘not-found’ does not exist. To see all available options pass `--help`.
        MSG
        refute(result.status)
      end

      def test_bump_preserve_empty_line
        @project.write("file1.rb", <<~RB)
          # typed: false

          class A; end
        RB

        result = @project.bundle_exec("spoom bump --no-color")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          Bumped `1` file from `false` to `true`:
           + file1.rb
        OUT
        refute(result.status)

        assert_equal(<<~RB, @project.read("file1.rb"))
          # typed: true

          class A; end
        RB
      end

      def test_multiple_constant_definitions
        @project.write("file1.rb", <<~CONTENTS)
          # typed: ignore
          class Bar; end
          Foo = Bar
        CONTENTS

        @project.write("file2.rb", <<~CONTENTS)
          # typed: false
          class Foo; end
        CONTENTS

        result = @project.bundle_exec("spoom bump --no-color --from ignore --to false")
        assert_empty(result.err)
        assert_equal(<<~OUT, result.out)
          Checking files...

          No file to bump from `ignore` to `false`
        OUT
        assert(result.status)
      end
    end
  end
end
