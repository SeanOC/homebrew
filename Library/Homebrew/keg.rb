#  Copyright 2009 Max Howell and other contributors.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
#  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
#  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
#  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
#  THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
class Keg <Pathname
  def initialize path
    super path
    raise "#{to_s} is not a valid keg" unless parent.parent.realpath == HOMEBREW_CELLAR.realpath
    raise "#{to_s} is not a directory" unless directory?
  end

  # if path is a file in a keg then this will return the containing Keg object
  def self.for path
    path = path.realpath
    while not path.root?
      return Keg.new(path) if path.parent.parent == HOMEBREW_CELLAR.realpath
      path = path.parent.realpath # realpath() prevents root? failing
    end
    raise "#{path} is not inside a keg"
  end

  def uninstall
    chmod_R 0777 # ensure we have permission to delete
    rmtree
    parent.rmdir_if_possible
  end

  def unlink
    n=0
    Pathname.new(self).find do |src|
      next if src == self
      dst=HOMEBREW_PREFIX+src.relative_path_from(self)
      next unless dst.symlink?
      dst.unlink
      n+=1
      Find.prune if src.directory?
    end
    n
  end

  def link
    $n=0
    $d=0

    mkpaths=(1..9).collect {|x| "man/man#{x}"} <<'man'<<'doc'<<'locale'<<'info'<<'aclocal'

    # yeah indeed, you have to force anything you need in the main tree into
    # these dirs REMEMBER that *NOT* everything needs to be in the main tree
    link_dir('etc') {:mkpath}
    link_dir('bin') {:skip}
    link_dir('sbin') {:link}
    link_dir('include') {:link}
    link_dir('share') {|path| :mkpath if mkpaths.include? path.to_s}

    link_dir('lib') do |path|
      case path.to_s
      when /^pkgconfig/ then :mkpath
      when /^php/ then :mkpath
      when /^perl5/ then :mkpath
      end
    end

    return $n+$d
  end

protected
  def resolve_any_conflicts dst
    # if it isn't a directory then a severe conflict is about to happen. Let
    # it, and the exception that is generated will message to the user about
    # the situation
    if dst.symlink? and dst.directory?
      src = (dst.parent+dst.readlink).cleanpath
      keg = Keg.for(src)
      dst.unlink
      keg.link_dir(src) { :mkpath }
      return true
    end
  end

  # symlinks the contents of self+foo recursively into /usr/local/foo
  def link_dir foo
    root = self+foo

    root.find do |src|
      next if src == root

      dst = HOMEBREW_PREFIX+src.relative_path_from(self)
      dst.extend ObserverPathnameExtension

      if src.file?
        dst.make_relative_symlink src
      elsif src.directory?
        # if the dst dir already exists, then great! walk the rest of the tree tho
        next if dst.directory? and not dst.symlink?

        # no need to put .app bundles in the path, the user can just use
        # spotlight, or the open command and actual mac apps use an equivalent
        Find.prune if src.extname.to_s == '.app'

        case yield src.relative_path_from(root)
        when :skip
          Find.prune
        when :mkpath
          dst.mkpath unless resolve_any_conflicts(dst)
        else
          unless resolve_any_conflicts(dst)
            dst.make_relative_symlink(src)
            Find.prune
          end
        end
      end
    end
  end
end
