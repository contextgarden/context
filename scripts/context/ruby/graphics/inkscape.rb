# module    : graphics/inkscape
# copyright : PRAGMA Advanced Document Engineering
# version   : 2002-2005
# author    : Hans Hagen
#
# project   : ConTeXt / eXaMpLe
# concept   : Hans Hagen
# info      : j.hagen@xs4all.nl
# www       : www.pragma-ade.com

# ['base/variables','variables'].each do |r| begin require r ; rescue Exception ; else break ; end ; end
# ['graphics/gs','gs'].each   do |r| begin require r ; rescue Exception ; else break ; end ; end

require 'base/variables'
require 'base/system'
require 'graphics/gs'

class InkScape

    include Variables

    def initialize(logger=nil)

        unless logger then
            puts('inkscape class needs a logger')
            exit
        end

        @variables = Hash.new
        @logger    = logger

        reset

    end

    def reset
        # nothing yet
    end

    def supported?(filename)
        filename =~ /.*\.(svg|svgz)/io
    end

    def convert(logfile=System.null)

        directpdf = false

        logfile = logfile.gsub(/\/+$/,"")

        inpfilename = getvariable('inputfile').dup
        outfilename = getvariable('outputfile').dup
        outfilename = inpfilename.dup if outfilename.empty?
        outfilename.gsub!(/(\.[^\.]*?)$/, ".pdf")
        tmpfilename = outfilename.gsub(/(\.[^\.]*?)$/, ".ps")

        if inpfilename.empty? || outfilename.empty? then
            report("no filenames given")
            return false
        end
        if inpfilename == outfilename then
            report("filenames must differ (#{inpfilename} #{outfilename})")
            return false
        end
        unless FileTest.file?(inpfilename) then
            report("unknown file #{inpfilename}")
            return false
        end

        # we need to redirect the error info else we get a pop up console

        if directpdf then
            report("converting #{inpfilename} to #{outfilename}")
          # resultpipe = "--without-gui --export-pdf=\"#{outfilename}\" 2>#{logfile}"
            resultpipe = "--without-gui --export-filename=\"#{outfilename}\" 2>#{logfile}"
        else
            report("converting #{inpfilename} to #{tmpfilename}")
            resultpipe = "--without-gui --print=\">#{tmpfilename}\" 2>#{logfile}"
        end

        arguments = [resultpipe,inpfilename].join(' ').gsub(/\s+/,' ')

        ok = true
        begin
            debug("inkscape: #{arguments}")
            # should work
            # ok = System.run('inkscape',arguments) # does not work here
            # but 0.40 only works with this:
            command = "inkscape #{arguments}"
            report(command)
            ok = system(command)
            # and 0.41 fails with everything
            # and 0.45 is better
        rescue
            report("aborted due to error")
            return false
        else
            return false unless ok
        end

        if not directpdf then
            ghostscript = GhostScript.new(@logger)
            ghostscript.setvariable('inputfile',tmpfilename)
            ghostscript.setvariable('outputfile',outfilename)
            report("converting #{tmpfilename} to #{outfilename}")
            ghostscript.convert
            begin
                File.delete(tmpfilename)
            rescue
            end
        end
    end

end
