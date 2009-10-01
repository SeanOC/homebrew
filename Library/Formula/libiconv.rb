require 'brewkit'

class Libiconv <Formula
  @url='http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.13.1.tar.gz'
  @homepage=''
  @md5='7ab33ebd26687c744a37264a330bbe9a'

# def deps
#   BinaryDep.new 'cmake'
# end

  def install
    system "./configure", "--prefix=#{prefix}", "--disable-debug", "--disable-dependency-tracking"
#   system "cmake . #{cmake_std_parameters}"
    system "make install"
  end
end
