# hans hagen, pragma-ade, hasselt nl
# experimental code, don't touch it

require 'rexml/document.rb'

class Array

  def downcase
    self.collect do |l|
        l.to_s.downcase
    end
  end

end

class Resource

  @@rslburl = 'http://www.pragma-ade.com/rng/rslb.rng'
  @@rslbns = 'rl'
  @@rslbtmp = 'rslbtool-tmp.xml'

  def initialize (filename='',namespace=@@rslbns)
    @ns = if namespace then @@rslbns + ':' else '' end
    set_filename(filename)
    @library = REXML::Document.new(skeleton,
      {:ignore_whitespace_nodes => :all,
       :compress_whitespace     => :all})
    @lastindex = 0
    @texexec = 'texexec'
    @downcaselabels = true
    @downcasefilenames = true
  end

  def keeplabelcase
    @downcaselabels = false
  end

  def keepfilenamecase
    @downcasefilenames = false
  end

  def outer_skeleton (str)
    tmp = if @ns.empty? then '' else " xmlns:#{@ns.sub(':','')}='#{@@rslburl}'" end
    "<?xml version='1.0'?>\n" + "<#{@ns}library#{tmp}>\n" + str + "\n</#{@ns}library>"
  end

  def skeleton
    outer_skeleton("<#{@ns}description>" +
          "<#{@ns}organization>unknown</#{@ns}organization>" +
          "<#{@ns}project>unknown</#{@ns}project>" +
          "<#{@ns}product>unknown</#{@ns}product>" +
          "<#{@ns}comment>unknown</#{@ns}comment>" +
       "</#{@ns}description>")
  end

  def set_filename (filename)
    @filename = if filename.empty? then 'unknown' else filename end
    @fullname = @filename
    @filename = File.basename(@filename).sub(/\..*$/,'')
  end

  def set_texexec (filename)
    print "setting texexec binary to: #{filename}\n"
    @texexec = filename
  end

  def load (filename='')
    set_filename(filename)
    if not filename.empty? and FileTest.file?(filename) # todo: test op valide fig base
      @library = REXML::Document.new(File.new(filename),
        {:ignore_whitespace_nodes => :all,
         :compress_whitespace     => :all})
      unless @library.root.prefix.empty?
        @ns = @library.root.prefix + ':'
      end
    else
      initialize(filename,!@ns.empty?)
    end
  end

  def save (filename)
    filename += '.xml' unless filename =~ /\..*?$/
    if not filename.empty? and f = open(filename,'w')
      @library.write(f,0)
      f.close
    end
  end

  def figure_labels
    REXML::XPath.match(@library.root,"/#{@ns}library/#{@ns}figure/#{@ns}label/text()")
  end

  def figure_records
    @library.elements.to_a("/#{@ns}library/#{@ns}figure")
  end

  def figure_files
    REXML::XPath.match(@library.root,"/#{@ns}library/#{@ns}figure/#{@ns}file/text()")
  end

  def delete_figure (label='')
    return if label.empty?
    labels = figure_labels
    labels.each_index do |i|
      if labels[i].to_s.downcase == label.downcase
        @library.elements.delete_all("/#{@ns}library/#{@ns}figure[#{i+1}]")
      end
    end
  end

  def add_figure (file='',label='',prefix='')
    return if file.empty? or file.match(/^#{@filename}\..*$/i)
    labels = figure_labels
    prefix = @filename if prefix.empty?
    if label.empty?
      i = @lastindex
      loop do
        i += 1
        label = prefix + ' ' + i.to_s
        break unless labels.include?(label)
      end
    else
      delete_figure(label) unless label.empty?
    end
    e = REXML::Element.new("#{@ns}figure")
    l = REXML::Element.new("#{@ns}label")
    f = REXML::Element.new("#{@ns}file")
    l.text, f.text = label, file
    e.add_element(l)
    e.add_element(f)
    @library.root.add_element(e)
  end

  def add_figures (list='',prefix='')
    if @downcasefilenames then
        files = figure_files.downcase
        [list].flatten.downcase.each do |f|
          next unless FileTest.file?(f)
          add_figure(f,'',prefix) unless files.include?(f)
        end
    else
        files = figure_files
        [list].flatten.each do |f|
          next unless FileTest.file?(f)
          add_figure(f,'',prefix) unless files.include?(f)
        end
    end
  end

  def delete_figures (list='')
    [list].flatten.downcase.each do |l|
      delete_figure(l)
    end
  end

  def sort_figures
    if @downcaselabels then
        labels = figure_labels.downcase
    else
        labels = figure_labels
    end
    return unless labels
    figures = figure_records
    @library.elements.delete_all("/#{@ns}library/#{@ns}figure")
    labels = labels.collect do |l| # prepare numbers
      l.gsub(/(\d+)/) do |d| sprintf('%05d', d) end
    end
    labels.sort.each do |s|
      @library.root.add_element(figures[labels.index(s)])
    end
  end

  def purge_figures
    REXML::XPath.each(@library.root,"/#{@ns}library/#{@ns}figure") do |e|
      filename = REXML::XPath.match(e,"#{@ns}file/text()").to_s
      e.parent.delete(e) unless FileTest.file?(filename)
    end
  end

  def run_command(command)
    print "calling #{command}\n"
    print "\n"
    begin
      system(command)
    rescue
      # sorry again
    end
    print "\n"
  end

  def create_dummies(process=false,result='',zipalso='')
    result = @filename if result.empty?
    list = REXML::XPath.match(@library.root,"/#{@ns}library/#{@ns}usage")
    begin
      File.delete(result+'.pdf')
    rescue
      # no way
    end
    return unless list && list.length>0
    done = Array.new
    list.each do |e|
      t = REXML::XPath.match(e,"#{@ns}type/text()")
      s = REXML::XPath.match(e,"#{@ns}state/text()")
      if t && (t.to_s == 'figure') && s && (s.to_s == 'missing')
        begin
          f = REXML::XPath.match(e,"#{@ns}file/text()").to_s
          if done.index(f)
            print "skipping dummy figure: " + f + "\n"
          elsif f =~ /\s/o
            print "skipping crappy fname: " + f + "\n"
          elsif f == 'dummy'
            print "skipping dummy figure: " + f + "\n"
          else
            print "creating dummy figure: " + f + "\n"
            if process && (x = open(@@rslbtmp,'w'))
              x.puts(outer_skeleton(e.to_s))
              x.close
              run_command ("#{@texexec} --pdf --once --batch --silent --random --use=res-10 --xml --result=#{f} #{@@rslbtmp}")
            end
            done.push(f+'.pdf')
            begin
              File.delete(@@rslbtmp)
            rescue
              # sorry once more
            end
          end
        rescue
          # sorry, skip 'm
        end
      end
    end
    if process && (done.length>0)
      begin
        File.delete(result + '.zip')
      rescue
         # ok
      end
      run_command("zip #{result+'.zip'} #{@fullname}")
      unless zipalso.empty?
        begin
            zipalso.split(',').each do |name|
                run_command("zip #{result+'.zip'} #{name}")
            end
        end
      end
      done.each do |name|
        run_command("zip #{result+'.zip'} #{name}")
      end
      run_command("#{@texexec} --pdf --batch --silent --use=res-11 --xml --result=#{result} #{@fullname}")
      done.each do |name|
        begin
          File.delete(name)
        rescue
          # sorry
        end
      end
    end
  end

end

# reslib = Resource.new
# reslib.load('f.xml')  # reslib.load('figbase.xml')
# reslib.delete_figure('figbase 5')
# reslib.delete_figure('figbase 5')
# reslib.add_figure('a.pdf')
# reslib.add_figure('b.pdf','something')
# reslib.add_figure('c.pdf')
# reslib.add_files('x.pdf')
# reslib.save('figbase.tmp')
