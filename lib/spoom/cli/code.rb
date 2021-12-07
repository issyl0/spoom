# typed: true
# frozen_string_literal: true

require "rbi"
require_relative '../code'

module Spoom
  module Cli
    class Code < Thor
      include Helper

      desc "sends", "List sends without signatures"
      def sends(*files)
        in_sorbet_project!

        path = exec_path
        config = sorbet_config
        files = Spoom::Sorbet.srb_files(config, path: path) if files.empty?

        if files.empty?
          say_error("No file matching `#{sorbet_config_file}`")
          exit(1)
        end

        say("Index `methods` from gem RBIs...")
        gem_rbis_files = Dir.glob("sorbet/rbi/gems/**/*.rbi").sort
        gem_rbis_trees = gem_rbis_files.map { |file| RBI::Parser.parse_file(file) }

        names_to_methods = Spoom::Code::FindGemMethods.new
        names_to_methods.visit_all(gem_rbis_trees)

        say("Collecting all `send` nodes...")
        collector = Spoom::Code::CollectSends.new
        files.each do |file|
          next if File.extname(file) == ".rbi"

          # file_strictness = Spoom::Sorbet::Sigils.file_strictness(file)
          # next if file_strictness == "false" || file_strictness == "ignore"

          collector.analyze_file(file)
        end

        matcher = Spoom::Code::SendAndSigMatcher.new(path)

        sends = T::Hash[String, T::Array[Spoom::Code::SendAndSig]].new

        say("Matching `send` nodes with signatures...")
        collector.sends.each do |send|
          send_and_sig = matcher.match_send(send)

          next if send_and_sig.has_sig?

          send_and_sigs = sends[send_and_sig.id] ||= []
          send_and_sigs << send_and_sig
        rescue Timeout::Error
          matcher = Spoom::Code::SendAndSigMatcher.new(path)
          next
        rescue Spoom::LSP::ResponseError
          next
        end

        sorted_keys = sends.keys.sort_by { |key| -(sends[key]&.size || 0) }

        puts "Top sends:"
        sorted_keys.each do |key|
          puts "#{sends[key]&.size || 0}\t#{key}"
          next unless key.match?(/<self>|<unknown>|T.untyped/)
          method_name = T.must(sends[key]&.first&.send&.method_name)
          candidates = names_to_methods.name_to_methods(method_name)
          candidates.each do |candidate|
            puts "\t\t #{candidate.fully_qualified_name} (#{candidate.loc})"
          end
        end

        matcher.stop
      end
    end
  end
end
