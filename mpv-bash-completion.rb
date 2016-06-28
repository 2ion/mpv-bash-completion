class MpvBashCompletion < Formula
  desc "Bash completion for the mpv video player"
  homepage "https://github.com/2ion/mpv-bash-completion"
  head "https://github.com/2ion/mpv-bash-completion.git"

  depends_on :x11
  depends_on "mpv"
  depends_on "lua"
  depends_on "bash"
  depends_on "coreutils"

  def install
    system "make", "-f", "Makefile.osx"
    system "make", "-f", "Makefile.osx", "install", "PREFIX=#{prefix}"
  end
end
