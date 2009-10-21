# = Introduction
# MP4Info supports the reading of tags and file info from MP4 audio files.
# It is based on the Perl module MP4::Info (http://search.cpan.org/~jhar/MP4-Info/)
# Note: MP4Info does not currently support Unicode strings.
#
# = License
# Copyright (c) 2004-2007 Jonathan Harris <jhar@cpan.org>
# Copyright (C) 2006-2007 Jason Terk <rain@xidus.net>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# See the README file for usage information.

require 'tempfile'

class MP4Info
  # Initialize a new MP4Info object from an IO object
  def initialize(io_stream)
    # Tag atoms
    @data_atoms = {
      "AART" => nil, "ALB" => nil, "ART" => nil, "CMT" => nil,
      "COVR" => nil, "CPIL" => nil, "CPRT" => nil, "DAY" => nil,
      "DISK" => nil, "GEN" => nil, "GNRE" => nil, "GRP" => nil,
      "NAM" => nil, "RTNG" => nil, "TMPO" => nil, "TOO" => nil,
      "TRKN" => nil, "WRT" => nil, "APID" => nil, "AKID" => nil,
      "ATID" => nil, "CNID" => nil, "GEID" => nil, "PLID" => nil,
      "TITL" => nil, "DSCP" => nil, "PERF" => nil, "AUTH" => nil
    }
    
    # Info atoms
    @info_atoms = {
      "VERSION" => nil, "BITRATE" => nil, "FREQUENCY" => nil, "MS" => nil,
      "SIZE" => nil, "SECS" => nil, "MM" => nil, "SS" => nil, "ENCRYPTED" => nil,
      "TIME" => nil, "COPYRIGHT" => nil, "LAYER" => nil
    }

    # Atoms that contain other atoms
    @container_atoms = {
      "ILST" => nil, "MDIA" => nil, "MINF" => nil, "MOOV" => nil,
      "STBL" => nil, "TRAK" => nil, "UDTA" => nil
    }
    
    # Non standard data atoms
    @other_atoms = {
      "MDAT" => :parse_mdat, "META" => :parse_meta,
      "MVHD" => :parse_mvhd, "STSD" => :parse_stsd,
      "MOOV" => :parse_moov, "UUID" => :parse_uuid
    }
    
    # Info/Tag aliases
    @aliases = {}
    
    # Just in case
    io_stream.binmode
    
    # Sanity check
    head = read_or_raise(io_stream, 8, "#{io_stream} does not appear to be an IO stream")
    raise "#{io_stream} does not appear to be an MP4 file" unless head[4..7].downcase == "ftyp"
    
    # Back to the beginning
    io_stream.rewind
    
    parse_container io_stream, 0, io_stream.stat.size
    
    @info_atoms["VERSION"] = 4
    @info_atoms["LAYER"] = 1 if @info_atoms["FREQUENCY"]
    if (@info_atoms["SIZE"] && @info_atoms["MS"])
      @info_atoms["BITRATE"] = ( 0.5 + @info_atoms["SIZE"] /
        ( ( @info_atoms["MM"] * 60 + @info_atoms["SS"] + (@info_atoms["MS"] * 1.0) / 1000 ) * 128 ) ).floor
    end
    @info_atoms["COPYRIGHT"] = true if @info_atoms["CPRT"]
  end

  # Get an MP4Info object from a file name
  def MP4Info.open(file_name)
    MP4Info.new(File.new(file_name))
  end
  
  # Dynamically get tags and info
  def method_missing(id)
    field = id.to_s
  
    if (@data_atoms.has_key?(field))
      @data_atoms[field]
    elsif (@info_atoms.has_key?(field))
      @info_atoms[field]
    elsif (@aliases.has_key?(field))
      @aliases[field]
    else
      nil
    end
  end
  
  private
    # Parse a container
    def parse_container(io_stream, level, size)
      level += 1
      container_end = io_stream.pos + size
      
      while io_stream.pos < container_end do
        parse_atom io_stream, level, container_end - io_stream.pos
      end
      
      if (io_stream.pos != container_end)
        raise "Parse error"
      end
    end
    
    # Parse an atom
    def parse_atom(io_stream, level, parent_size)
      head = read_or_raise(io_stream, 8, "Premature end of file")
      
      size, id = head.unpack("Na4")
      
      if (size == 0)
        position = io_stream.pos
        io_stream.seek(0, 2)
        size = io_stream.pos - position
        io_stream.seek(position, 0)
      elsif (size == 1)
        # Extended size, whatever that means
        head = read_or_raise(io_stream, 8, "Premature end of file")
        hi, low = head.unpack("NN")
        size = hi * (2**32) + low - 16
        
        if (size > parent_size)
          # Atom extends outside of parent container; skip to the end
          io_stream.seek(parent_size - 16, 1)
          return
        end
        
        size -= 16
      else
        if (size > parent_size)
          # Atom extends outside of parent container; skip to the end
          io_stream.seek(parent_size - 8, 1)
          return
        end
        
        size -= 8;
      end
      
      if (size < 0)
        raise "Parse error"
      end
      
      if id[0] == 169 
        # strip copyright sign at the beginning
        id = id[1..-1]
      end
      id = id.upcase
      
      printf "%s%s: %d bytes\n", ' ' * ( 2 * level ), id, size if $DEBUG
      
      if (@data_atoms.has_key?(id))
        parse_data io_stream, level, size, id
      elsif (@other_atoms.has_key?(id))
        self.send(@other_atoms[id], io_stream, level, size)
      elsif (@container_atoms.has_key?(id))
        parse_container io_stream, level, size
      else
        # Unknown atom, move on
        io_stream.seek size, 1
      end
    end
    
    # Parse a MOOV container
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_moov(io_stream, level, size)
      data = read_or_raise(io_stream, size, "Premature end of file")
      
      cache = Tempfile.new "mp4info"
      
      # required for Windows
      cache.binmode
      
      cache.write data
      cache.open
      cache.rewind
      
      parse_container(cache, level, size)
      
      cache.close!
    end
    
    # Parse an MDAT atom
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_mdat(io_stream, level, size)
      @info_atoms["SIZE"] = 0 unless @info_atoms["SIZE"]
      @info_atoms["SIZE"] += size
      io_stream.seek(size, 1)
    end
    
    # Parse a META atom
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_meta(io_stream, level, size)
      # META is a container preceeded by a version field
      io_stream.seek(4, 1)
      parse_container(io_stream, level, size - 4)
    end
    
    # Parse an MVHD atom
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_mvhd(io_stream, level, size)
      raise "Parse error" if size < 32
      data = read_or_raise(io_stream, size, "Premature end of file")
      
      version = data.unpack("C")[0] & 255
      if (version == 0)
        scale, duration = data[12..19].unpack("NN")
      elsif (version == 1)
        scale, hi, low = data[20..31].unpack("NNN")
        duration = hi * (2**32) + low
      else
        return
      end
      
      printf "  %sDur/Scl=#{duration}/#{scale}\n", ' ' * ( 2 * level ) if $DEBUG
      
      secs                = (duration * 1.0) / scale
      @info_atoms["SECS"] = (secs).round
      @info_atoms["MM"]   = (secs / 60).floor
      @info_atoms["SS"]   = (secs - @info_atoms["MM"] * 60).floor
      @info_atoms["MS"]   = (1000 * (secs - secs.floor)).round
      @info_atoms["TIME"] = sprintf "%02d:%02d", @info_atoms["MM"],
                            @info_atoms["SECS"] - @info_atoms["MM"] * 60;
    end
    
    # Parse an STSD atom
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_stsd(io_stream, level, size)
      raise "Parse error" if size < 44
      data = read_or_raise(io_stream, size, "Premature end of headers")
      
      printf "  %sSample=%s\n", ' ' * ( 2 * level ), data[12..15] if $DEBUG
      
      data_format = data[12..15].downcase
      
      # Is this an audio track?
      if (data_format == "mp4a" || data_format == "drms" ||
          data_format == "samr" || data_format == "sawb" ||
          data_format == "sawp" || data_format == "enca" ||
          data_format == "alac" )
        @info_atoms["ENCODING"] = data_format
        @info_atoms["FREQUENCY"] = (data[40..43].unpack("N")[0] * 1.0) / 65536000
        printf "  %sFreq=%s\n", ' ' * ( 2 * level ), @info_atoms["FREQUENCY"] if $DEBUG
      end
      
      if (data_format == "drms" || data_format[0..2] == "enc")
        @info_atoms["ENCRYPTED"] = true;
      end
    end

    # User-defined box. Used by PSP - See ffmpeg libavformat/movenc.c
    #
    # Pre-conditions: size = size of atom contents
    #                 io_stream points to start of atom contents
    #
    # Post-condition: io_stream points past end of atom contents
    def parse_uuid(io_stream, level, size)
      data = read_or_raise(io_stream, size, "Premature end of file")
      
      return unless size > 26
      
      u1, u2, u3, u4 = data.unpack 'a4NNN'
      
      if (u1 == "USMT")
        pspsize, pspid = data[16..23].unpack 'Na4'
        
        return unless pspsize == size - 16
        
        if (pspid == "MTDT")
          nblocks = data[24..25].unpack 'n'
          data = data[26..(data.length - 1)]
          
          while nblocks
            bsize, btype, flags, ptype = data.unpack 'nNnn'
            
            if (btype == 1 && bsize == 12 &&
                ptype == 1 && @data_atoms["NAM"].nil?)
              @data_atoms["NAM"] = data[10..(10 + bsize - 11)]
            elsif (btype == 4 && bsize > 12 && ptype == 1)
              @data_atoms["TOO"] = data[10..(10 + bsize - 11)]
            end
            
            data = data[bsize..(data.length - 1)]
            nblocks -= 1
          end
        end
      end
    end
    
    def parse_data(io_stream, level, size, id)
      # Possible genres...
      mp4_genres = [
        'N/A',               'Blues',
        'Classic Rock',      'Country',
        'Dance',             'Disco',
        'Funk',              'Grunge',
        'Hip-Hop',           'Jazz',
        'Metal',             'New Age',
        'Oldies',            'Other',
        'Pop',               'R&B',
        'Rap',               'Reggae',
        'Rock',              'Techno',
        'Industrial',        'Alternative',
        'Ska',               'Death Metal',
        'Pranks',            'Soundtrack',
        'Euro-Techno',       'Ambient',
        'Trip-Hop',          'Vocal',
        'Jazz+Funk',         'Fusion',
        'Trance',            'Classical',
        'Instrumental',      'Acid',
        'House',             'Game',
        'Sound Clip',        'Gospel',
        'Noise',             'AlternRock',
        'Bass',              'Soul',
        'Punk',              'Space',
        'Meditative',        'Instrumental Pop',
        'Instrumental Rock', 'Ethnic',
        'Gothic',            'Darkwave',
        'Techno-Industrial', 'Electronic',
        'Pop-Folk',          'Eurodance',
        'Dream',             'Southern Rock',
        'Comedy',            'Cult',
        'Gangsta',           'Top 40',
        'Christian Rap',     'Pop/Funk',
        'Jungle',            'Native American',
        'Cabaret',           'New Wave',
        'Psychadelic',       'Rave',
        'Showtunes',         'Trailer',
        'Lo-Fi',             'Tribal',
        'Acid Punk',         'Acid Jazz',
        'Polka',             'Retro',
        'Musical',           'Rock & Roll',
        'Hard Rock',         'Folk',
        'Folk/Rock',         'National Folk',
        'Swing',             'Fast-Fusion',
        'Bebob',             'Latin',
        'Revival',           'Celtic',
        'Bluegrass',         'Avantgarde',
        'Gothic Rock',       'Progressive Rock',
        'Psychedelic Rock',  'Symphonic Rock',
        'Slow Rock',         'Big Band',
        'Chorus',            'Easy Listening',
        'Acoustic',          'Humour',
        'Speech',            'Chanson',
        'Opera',             'Chamber Music',
        'Sonata',            'Symphony',
        'Booty Bass',        'Primus',
        'Porn Groove',       'Satire',
        'Slow Jam',          'Club',
        'Tango',             'Samba',
        'Folklore',          'Ballad',
        'Power Ballad',      'Rhythmic Soul',
        'Freestyle',         'Duet',
        'Punk Rock',         'Drum Solo',
        'A capella',         'Euro-House',
        'Dance Hall',        'Goa',
        'Drum & Bass',       'Club House',
        'Hardcore',          'Terror',
        'Indie',             'BritPop',
        'NegerPunk',         'Polsk Punk',
        'Beat',              'Christian Gangsta',
        'Heavy Metal',       'Black Metal',
        'Crossover',         'Contemporary C',
        'Christian Rock',    'Merengue',
        'Salsa',             'Thrash Metal',
        'Anime',             'JPop',
        'SynthPop'
      ]
      
      data = read_or_raise(io_stream, size, "Premature end of file")
      
      if (id == "TITL" || id == "DSCP" || id == "CPRT" ||
          id == "PERF" || id == "AUTH" || id == "GNRE")
        ver = data.unpack("N")[0]
        if (ver == 0)
          return unless size > 7
          size -= 7
          type = 1
          data = data[6..(6 + size - 1)]
          
          if (id == "TITL")
            return if !@data_atoms["NAM"].nil?
            id = "NAM"
          elsif (id == "DSCP")
            return if !@data_atoms["CMT"].nil?
            id = "CMT"
          elsif (id == "PERF")
            return if !@data_atoms["ART"].nil?
            id = "ART"
          elsif (id == "AUTH")
            return if !@data_atoms["WRT"].nil?
            id = "WRT"
          end
        end
      end
        
      if (id == "MEAN" || id == "NAME" || id == "DATA")
        if id == "DATA"
          data = data[8..(data.length - 1)]
        else
          data = data[4..(data.length - 1)]
        end
        
        @data_atoms[id] = data
        return
      end
      
      if (type.nil?)
        return unless size > 16
        size, atom, type = data.unpack("Na4N")
        
        return unless atom.downcase == "data" and size > 16
        
        size = size - 16
        type = type & 255
        data = data[16..(16 + size - 1)]
      end
      
      printf "  %sType=#{type}, Size=#{size}\n", ' ' * ( 2 * level ) if $DEBUG
      
      if (id == "COVR")
        @data_atoms[id] = data
      elsif (type == 0)
        ints = data.unpack("n" * (size / 2))
        if (id == "GNRE")
          @data_atoms[id] = mp4_genres[ints[0]]
        elsif (id == "DISK" || id == "TRKN")
          @data_atoms[id] = [ints[1], (size >= 6 ? ints[2] : 0)] if size >= 4
        elsif (size >= 4)
          @data_atoms[id] = ints[1]
        end
      elsif (type == 1)
        if (id == "GEN")
          return if !@data_atoms["GNRE"].nil?
          id = "GNRE"
        elsif (id == "AART")
          return if !@data_atoms["ART"].nil?
          id = "ART"
        elsif (id == "DAY")
          data = data[0..3]
          return if data == 0
        end
        
        @data_atoms[id] = data
      elsif (type == 21)
        if (size == 1)
          @data_atoms[id] = data.unpack("C")[0]
        elsif (size == 2)
          @data_atoms[id] = data.unpack("n")[0]
        elsif (size == 4)
          @data_atoms[id] = data.unpack("N")[0]
        elsif (size == 8)
          hi, low = data.unpack("NN")
          @data_atoms[id] = hi * (2 ** 32) + low
        else
          @data_atoms[id] = data
        end
      elsif (type == 13 || type == 14)
        @data_atoms[id] = data
      end
    end
    
    # Utility method; read bytes bytes from io_stream or raise message message
    def read_or_raise(io_stream, bytes, message)
      buffer = io_stream.read(bytes)
      if (buffer.length != bytes)
        raise message
      end
      buffer
    end
end
