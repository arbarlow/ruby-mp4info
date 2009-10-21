#!/usr/bin/env ruby

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

$KCODE="u"
$:.unshift File.join(File.dirname(__FILE__), "..", "lib")
require "mp4info"
require "test/unit"

# Tests for MP4Info
#
# This test case covers a small number of possible encoders and
# tag/info fields. More cases are needed to fully test the library.
class TestMP4Info < Test::Unit::TestCase
  
  # Test an mp4 file created by the FAAC encoder
  def test_faac
    file = "faac.m4a"

    info = {
      :ALB => 'Album',
      :APID => nil,
      :ART => 'Artist',
      :CMT => 'This is a Comment',
      :COVR => nil,
      :CPIL => 1,
      :CPRT => nil,
      :DAY => '2004',
      :DISK => [3,4],
      :GNRE => 'Acid Jazz',
      :GRP => nil,
      :NAM => 'Name',
      :TMPO => nil,
      :TOO => 'FAAC 1.24+ (Jul 14 2004) UNSTABLE',
      :TRKN => [1,2],
      :WRT => 'Composer',
      :VERSION	=> 4,
      :LAYER	=> 1,
      :BITRATE	=> 16,
      :FREQUENCY => 8,
      :SIZE	=> 2353,
      :SECS	=> 1,
      :MM	=> 0,
      :MS	=> 178,
      :SS	=> 1,
      :TIME	=> '00:01',
      :COPYRIGHT => nil,
      :ENCRYPTED => nil
    }
    
    mp4 = MP4Info.open(file)
    
    info.each do |key, value|
      assert_equal(value, mp4.send(key))
    end
  end
  
  # Test an mp4 file created by the iTunes encoder
  def test_itunes
    file = "iTunes.m4a"
    
    info = {
      :ALB => 'Album',
      :APID => nil,
      :ART => 'Artist',
      :CMT => "Comment\r\n2nd line",
      :COVR => nil,
      :CPIL	=> 0,
      :CPRT => nil,
      :DAY => '2004',
      :DISK	=> [3,4],
      :GNRE	=> 'Acid Jazz',
      :GRP => 'Grouping',
      :NAM => 'Name',
      :TMPO	=> 100,
      :TOO => 'iTunes v4.6.0.15, QuickTime 6.5.1',
      :TRKN	=> [1,2],
      :WRT => 'Composer',
      :VERSION => 4,
      :LAYER => 1,
      :BITRATE => 50,
      :FREQUENCY => 44.1,
      :SIZE	=> 6962,
      :SECS	=> 1,
      :MM	=> 0,
      :SS	=> 1,
      :MS	=> 90,
      :TIME	=> '00:01',
      :COPYRIGHT => nil,
      :ENCRYPTED => nil
    }
    
    mp4 = MP4Info.open(file)
    
    info.each do |key, value|
      assert_equal(value, mp4.send(key))
    end
  end
  
  # Test an mp4 file created by the Nero encoder
  def test_nero
    file = "nero.mp4"
    
    info = {
      :ALB => nil,
      :APID => nil,
      :ART => 'Artist',
      :CMT => nil,
      :COVR => nil,
      :CPIL => nil,
      :CPRT => nil,
      :DAY => nil,
      :DISK => nil,
      :GNRE => nil,
      :GRP => nil,
      :NAM => 'Name',
      :TMPO => nil,
      :TOO => 'Nero AAC Codec 2.9.9.91',
      :TRKN => nil,
      :WRT => nil,
      :VERSION => 4,
      :LAYER => 1,
      :BITRATE => 21,
      :FREQUENCY => 8,
      :SIZE	=> 3030,
      :SECS	=> 1,
      :MM	=> 0,
      :SS	=> 1,
      :MS	=> 153,
      :TIME	=> '00:01',
      :COPYRIGHT => nil,
      :ENCRYPTED => nil
    }
    
    mp4 = MP4Info.open(file)
    
    info.each do |key, value|
      assert_equal(value, mp4.send(key))
    end
  end
  
  # Test an mp4 file created by the Real (Helix Producer) encoder
  #
  # This test will fail because MP4Info does not support Unicode
  # strings; see bug 3512
  # (http://rubyforge.org/tracker/index.php?func=detail&aid=3512&group_id=1175&atid=4589)
  def test_real
    file = "real.m4a"
    
    info = {
      :ALB	=> 'Album',
      :APID => nil,
      :ART	=> 'AÆtist',
      :CMT	=> 'Comment',
      :COVR => nil,
      :CPIL => nil,
      :CPRT => nil,
      :DAY	=> "2004",
      :DISK => [0, 0],
      :GNRE	=> 'Acid Jazz',
      :GRP => nil,
      :NAM	=> 'N™me',
      :TMPO => nil,
      :TOO	=> 'Helix Producer SDK 10.0 for Windows, Build 10.0.0.240',
      :TRKN	=> [1,0],
      :WRT => nil,
      :VERSION	=> 4,
      :LAYER	=> 1,
      :BITRATE	=> 93,
      :FREQUENCY => 1,	# What part of "the sampling rate of the audio should be ... documented in the samplerate field" don't Real understand?
      :SIZE	=> 131682,
      :SECS	=> 11,
      :MM	=> 0,
      :SS	=> 11,
      :MS	=> 53,
      :TIME	=> '00:11',
      :COPYRIGHT => nil,
      :ENCRYPTED => nil
    }
    
    mp4 = MP4Info.open(file)
    
    info.each do |key, value|
      assert_equal(value, mp4.send(key), "bad #{key}")
    end
  end
end
