# typed: strict
# frozen_string_literal: true

module Spoom
  module Sorbet
    module TUnsafe
      extend T::Sig

      REGEXP = T.let(/T\.unsafe\(/.freeze, Regexp)

      sig { params(file: String).returns(Integer) }
      def self.t_unsafes_in_file(file)
        File.read(file).scan(REGEXP).size
      end

      sig { params(files: T::Array[String]).returns(Integer) }
      def self.t_unsafes_in_files(files)
        files.sum { |file| t_unsafes_in_file(file) }
      end
    end
  end
end
