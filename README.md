## el_finder

[![Gem Version](https://badge.fury.io/rb/el_finder.png)](http://badge.fury.io/rb/el_finder)

* http://elrte.org/redmine/projects/elfinder

## Description:

Ruby library to provide server side functionality for elFinder.  elFinder is an
open-source file manager for web, written in JavaScript using jQuery UI.

## 2.x API support:

This is an attempt to implement elFinder 2.x API, currently implemented commands:

* open
* file
* rm
* mkdir
* upload

Todo:

* tests (currently no tests for 2.x API)
* implement missing API commands
* implement permissions/options

## Requirements:

The gem, by default, relies upon the 'image_size' ruby gem and ImageMagick's 'mogrify' and 'convert' commands.
These requirements can be changed by implementing custom methods for determining image size
and resizing of an image.

NOTE: There is another ruby gem 'imagesize' that also defines the class ImageSize and requires 'image_size'
If you have that one installed, elfinder will fail.  Make sure you only have 'image_size' installed if you use
the defaults.

## Install:

* Install elFinder (http://elrte.org/redmine/projects/elfinder/wiki/Install_EN)
* Install ImageMagick (http://www.imagemagick.org/)
* Do whatever is necessary for your Ruby framework to tie it together.

### Rails 4

* Add `gem 'el_finder', git: "https://github.com/ThompZon/el_finder.git", :branch => 'api-v2'` to Gemfile
* % bundle install
* Switch to using jQuery instead of Prototype
* Add `config.assets.precompile += %w( jquery-ui.css elFinder/main.js elFinder/js/elfinder.min.js  elFinder/css/elfinder.min.css)` to config/application.rb
- Note elFinder version may be in path, it might be easier to debug using elfinder.full.js and css instead of the "min"-versions
* Add the following action to a controller of your choosing.

```ruby
  skip_before_filter :verify_authenticity_token, :only => ['elfinder']

  def index
  end

  def elfinder
    h, r = ElFinder::Connector.new(
      :root => File.join(Rails.public_path, 'public'),
      :url => '/system/elfinder',
      :perms => {
        /^(Welcome|README)$/ => {:read => true, :write => false, :rm => false},
        '.' => {:read => true, :write => false, :rm => false}, # '.' is the proper way to specify the home/root directory.
        /^test$/ => {:read => true, :write => true, :rm => false},
        'logo.png' => {:read => true},
        /\.png$/ => {:read => false} # This will cause 'logo.png' to be unreadable.  
                                     # Permissions err on the safe side. Once false, always false.
      },
      :extractors => { 
        'application/zip' => ['unzip', '-qq', '-o'], # Each argument will be shellescaped (also true for archivers)
        'application/x-gzip' => ['tar', '-xzf'],
      },
      :archivers => { 
        'application/zip' => ['.zip', 'zip', '-qr9'], # Note first argument is archive extension
        'application/x-gzip' => ['.tgz', 'tar', '-czf'],
        },
      :tree_sub_folders => true,
      #adds {Rails.root}/public/uploads as "root" volume, named "uploads" in the GUI
      :volumes => [{:id => "root", :name => "uploads", :root => File.join(Rails.root, 'public', 'uploads'), :url => "files/"}],
      :mime_handler => ElFinder::MimeType,
      :image_handler => ElFinder::Image,
      :original_filename_method => lambda { |file| file.original_filename.respond_to?(:force_encoding) ? file.original_filename.force_encoding('utf-8') : file.original_filename },
      :disabled_commands => [],
      :allow_dot_files => true,
      :upload_max_size => '50M',
      :upload_file_mode => 0644,
      :home => 'Home',
      :default_perms => { :read => true, :write => true, :rm => true, :hidden => false },
      :thumbs => false,
      :thumbs_directory => '.thumbs',
      :thumbs_size => 48,
      :thumbs_at_once => 5,
    ).run(params)

    headers.merge!(h)

    render (r.empty? ? {:nothing => true} : {:text => r.to_json}), :layout => false
  end
```

* Add the appropriate route to config/routes.rb such as:

```ruby
  match 'elfinder' => 'files#elfinder', via: [:get, :post]
```

* Add the following to your layout. The paths may be different depending 
on where you installed the various js/css files.

```haml
= stylesheet_link_tag 'jquery-ui', 'elFinder-2.1.26/css/elfinder.min.css'
= javascript_include_tag "elFinder-2.1.26/js/elfinder.min.js"
```

* Add the following to the view that will display elFinder:

```haml
:javascript
  $().ready(function() { 
    $('#elfinder').elfinder({ 
      url: '/elfinder',
      lang: 'en',
      height: 700,
    })
  })
#elfinder
```

* That's it.  I think.  If not, check out the example rails application at http://github.com/phallstrom/el_finder-rails-example.

## Using with very large file systems

@gudata added a configuration option to not load child directories.  This breaks V1, but if you are using V2
it should work and speed up the responsiveness quite a bit.  To enable it set `:tree_sub_folders` to `false`.

## License:

(The MIT License)

Copyright (c) 2010 Philip Hallstrom

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
