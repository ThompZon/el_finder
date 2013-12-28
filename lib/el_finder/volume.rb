module ElFinder
  class Volume

    attr_reader :id, :name, :root, :url

    def initialize(options)
      [:id, :name, :root, :url].each do |opt|
        raise(ArgumentError, "Missing required #{opt} option") unless options.key?(opt)
      end

      @id   = options[:id]
      @name = options[:name]
      @root = options[:root]
      @url  = options[:url]

      @options = {
        upload_file_mode: 0644,
        original_filename_method: lambda { |file| file.original_filename.respond_to?(:force_encoding) ? file.original_filename.force_encoding('utf-8') : file.original_filename }
      }
    end

    def contains?(hash)
      hash.start_with?("#{@id}_")
    end

    def pathname(target)
      ElFinder::Pathname.new(@root, target)
    end

    def decode(hash)
      hash = hash.slice(("#{@id}_".length)..-1) if hash.start_with?("#{@id}_")
      hash = hash.tr('-_.', '+/=')
      # restore missing '='
      len = hash.length % 4
      hash += '==' if len == 1 or len == 2
      hash += '='  if len == 3
      path = Base64.strict_decode64(hash)
      ElFinder::Pathname.new(@root, path)
    end

    def encode(path)
      # creates hash for the path
      path = ElFinder::Pathname.new(@root, path).path.to_s
      hash = Base64.strict_encode64(path)
      hash.tr!('+/=', '-_.')
      hash.gsub!(/\.+\Z/, '')
      "#{@id}_#{hash}"
    end

    def cwd(target = '.')
#       {
#     "name"   : "Images",             // (String) name of file/dir. Required
#     "hash"   : "l0_SW1hZ2Vz",        // (String) hash of current file/dir path, first symbol must be letter, symbols before _underline_ - volume id, Required.
#     "phash"  : "l0_Lw",              // (String) hash of parent directory. Required except roots dirs.
#     "mime"   : "directory",          // (String) mime type. Required.
#     "ts"     : 1334163643,           // (Number) file modification time in unix timestamp. Required.
#     "date"   : "30 Jan 2010 14:25",  // (String) last modification time (mime). Depricated but yet supported. Use ts instead.
#     "size"   : 12345,                // (Number) file size in bytes
#     "dirs"   : 1,                    // (Number) Only for directories. Marks if directory has child directories inside it. 0 (or not set) - no, 1 - yes. Do not need to calculate amount.
#     "read"   : 1,                    // (Number) is readable
#     "write"  : 1,                    // (Number) is writable
#     "locked" : 0,                    // (Number) is file locked. If locked that object cannot be deleted and renamed
#     "tmb"    : 'bac0d45b625f8d4633435ffbd52ca495.png' // (String) Only for images. Thumbnail file name, if file do not have thumbnail yet, but it can be generated than it must have value "1"
#     "alias"  : "files/images",       // (String) For symlinks only. Symlink target path.
#     "thash"  : "l1_c2NhbnMy",        // (String) For symlinks only. Symlink target hash.
#     "dim"    : "640x480"             // (String) For images - file dimensions. Optionally.
#     "volumeid" : "l1_"               // (String) Volume id. For root dir only.
# }
      # {
      #   name: @name,
      #   hash: encode('.'),
      #   mime: 'directory',
      #   ts: File.mtime(@root).to_i,
      #   size: 0,
      #   dirs: 0,
      #   read: 1,
      #   write: 1,
      #   locked: 0,
      #   volumeid: "#{@id}_"
      # }
      path_info(ElFinder::Pathname.new(@root, target))
    end

    def files(target = '.')
      target = ElFinder::Pathname.new(@root, target)
      files = target.children.map{|p| path_info(p)}
      files << cwd(target)
      files
    end

    def tree(target)
      tree = root.child_directories(@options[:tree_sub_folders])

      # reject{ |child|
      #   ( @options[:thumbs] && child.to_s == @thumb_directory.to_s ) || perms_for(child)[:hidden]
      # }.
      # sort_by{|e| e.basename.to_s.downcase}.
      # map { |child|
      #     {:name => child.basename.to_s,
      #      :hash => to_hash(child),
      #      :dirs => tree_for(child),
      #     }.merge(perms_for(child))
      # }
    end

    def path_info(target)
      is_dir = File.directory?(target.realpath)
      mime = is_dir ? 'directory' : 'file'
      name = @name if target.is_root?
      name ||= target.basename.to_s

      dirs = 0
      if is_dir
        # check if has sub directories
        dirs = 1 if Dir[File.join(target.realpath, '*/')].count > 0
      end

      size = 0
      unless is_dir
        size = File.size(target.realpath)
      end

      result = {
        name: name,
        hash: encode(target.path.to_s),
        mime: mime,
        ts: File.mtime(target.realpath).to_i,
        size: size,
        dirs: dirs,
        read: 1,
        write: 1,
        locked: 0
      }
      if target.is_root?
        result[:volumeid] = "#{@id}_"
      else
        result[:phash] = encode(target.dirname.path.to_s)
      end

      result
    end

    def upload(target, upload_files)
      # if perms_for(@current)[:write] == false
      #   @response[:error] = 'Access Denied'
      #   return
      # end
      target = ElFinder::Pathname.new(@root, target)
      response = {}
      select = []
      added = []
      upload_files.to_a.each do |file|
        if file.respond_to?(:tempfile)
          the_file = file.tempfile
        else
          the_file = file
        end
        if upload_max_size_in_bytes > 0 && File.size(the_file.path) > upload_max_size_in_bytes
          response[:error] ||= "Some files were not uploaded"
          response[:errorData][@options[:original_filename_method].call(file)] = 'File exceeds the maximum allowed filesize'
        else
          dst = target + @options[:original_filename_method].call(file)
          the_file.close
          src = the_file.path
          FileUtils.mv(src, dst.fullpath)
          FileUtils.chmod @options[:upload_file_mode], dst
          select << encode(dst)
          added << path_info(dst)
        end
      end
      response[:select] = select unless select.empty?
      response[:added] = added unless added.empty?
      response
    end

    def mkdir(target, name)
      # if perms_for(@current)[:write] == false
      #   @response[:error] = 'Access Denied'
      #   return
      # end

      response = {}
      dir = ElFinder::Pathname.new(@root, target) + name
      if !dir.exist? && dir.mkdir
        response[:added] = [path_info(dir)]
      else
        response[:error] = "Unable to create folder"
      end
      response
    end

    def rm(target)
      target = ElFinder::Pathname.new(@root, target)
      remove_target(target)
    end

    def remove_target(target)
      target = ElFinder::Pathname.new(@root, target)
      response = {}
      if target.directory?
        target.children.each do |child|
          remove_target(child)
        end
      end
      # if perms_for(target)[:rm] == false
      #   @response[:error] ||= 'Some files/directories were unable to be removed'
      #   @response[:errorData][target.basename.to_s] = "Access Denied"
      # else
        begin
          target.unlink
          # if @options[:thumbs] && (thumbnail = thumbnail_for(target)).file?
          #   thumbnail.unlink
          # end
          [true, encode(target)]
        rescue
          [false, encode(target)]
          # @response[:error] ||= 'Some files/directories were unable to be removed'
          # @response[:errorData][target.basename.to_s] = "Remove failed"
        end
      # end
    end

    def upload_max_size_in_bytes
      999999999
    end

  end
end