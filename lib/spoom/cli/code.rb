# typed: true
# frozen_string_literal: true

require_relative '../code'

module Spoom
  module Cli
    class Code < Thor
      include Helper

      desc "sends", "List sends"
      def sends(*files)
        in_sorbet_project!

        path = exec_path
        config = sorbet_config
        files = Spoom::Sorbet.srb_files(config, path: path) if files.empty?

        if files.empty?
          say_error("No file matching `#{sorbet_config_file}`")
          exit(1)
        end

        collector = Spoom::Code::CollectSends.new
        files.each do |file|
          next if File.extname(file) == ".rbi"
          collector.analyze_file(file)
        end

        matcher = Spoom::Code::SendAndSigMatcher.new(path)

        sends = T::Hash[String, T::Array[Spoom::Code::SendAndSig]].new

        collector.sends.each do |send|
          send_and_sig = matcher.match_send(send)

          next if send_and_sig.has_sig?
          next if send_and_sig.recv_type == "T.untyped"

          send_and_sigs = sends[send_and_sig.id] ||= []
          send_and_sigs << send_and_sig
        end

        sorted_keys = sends.keys.sort_by { |key| -(sends[key]&.size || 0) }

        puts "Top untyped sends:"
        sorted_keys.each do |key|
          puts "#{sends[key]&.size || 0}\t#{key}"
        end

        matcher.stop
      end
    end
  end
end
