# typed: strict
# frozen_string_literal: true

module Spoom
  module Code
    class SendAndSig
      extend T::Sig

      sig { returns(Send) }
      attr_reader :send

      sig { returns(T.nilable(String)) }
      attr_reader :recv_type

      sig { returns(T.nilable(String)) }
      attr_reader :method_sig

      sig { params(send: Send, recv_type: T.nilable(String), method_sig: T.nilable(String)).void }
      def initialize(send, recv_type:, method_sig:)
        @send = send
        @recv_type = recv_type
        @method_sig = method_sig
      end

      sig { returns(T::Boolean) }
      def has_sig?
        @method_sig != nil
      end

      sig { returns(String) }
      def id
        "#{recv_type || '<unknown>'}##{send.method_name}"
      end

      sig { returns(String) }
      def to_s
        "Calling `#{id}`: #{has_sig? ? method_sig : 'no sig'} (#{send.loc})"
      end
    end

    class SendAndSigMatcher
      extend T::Sig

      sig { params(project_root: String, sorbet_bin_path: String).void }
      def initialize(project_root, sorbet_bin_path: Spoom::Sorbet::BIN_PATH)
        @project_root = project_root
        @lsp_root = T.let(File.expand_path(project_root), String)
        @sorbet_bin_path = sorbet_bin_path

        @lsp = T.let(Spoom::LSP::Client.new(
          @sorbet_bin_path,
          "--lsp",
          "--enable-all-experimental-lsp-features",
          "--disable-watchman",
          path: @lsp_root
        ), Spoom::LSP::Client)

        @lsp.open(@lsp_root)
      end

      sig { params(send: Send).returns(SendAndSig) }
      def match_send(send)
        # puts send
        recv_loc = send.recv_loc
        recv_type = nil

        if recv_loc
          recv_hover = @lsp.hover(
            to_uri(recv_loc.file),
            recv_loc.begin_line - 1,
            recv_loc.begin_column + 1
          )
          recv_type = parse_type_from_hover_contents(recv_hover)
        else
          recv_type = "<self>"
        end

        send_hover = @lsp.hover(
          to_uri(send.selector_loc.file),
          send.selector_loc.begin_line - 1,
          send.selector_loc.begin_column + 1
        )

        method_sig = parse_type_from_hover_contents(send_hover)
        SendAndSig.new(send, recv_type: recv_type, method_sig: method_sig)
      end

      sig { void }
      def stop
        @lsp.close
      end

      private

      sig { params(path: String).returns(String) }
      def to_uri(path)
        "file://" + File.join(@lsp_root, path)
      end

      sig { params(hover: T.nilable(LSP::Hover)).returns(T.nilable(String)) }
      def parse_type_from_hover_contents(hover)
        contents = hover&.contents
        return nil unless contents
        return nil if contents.empty?
        type = contents.lines.first&.strip
        if type&.match?(/^sig/)
          type = type.gsub(/.*returns\((.*)\).*/, "\\1")
        end
        type
      end
    end
  end
end
