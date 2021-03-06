#!/usr/bin/env ruby

require 'optparse'
require 'bio-logger'
require 'bio'

SCRIPT_NAME = File.basename(__FILE__); LOG_NAME = SCRIPT_NAME.gsub('.rb','')

# Parse command line options into the options hash
options = {
  :logger => 'stderr',
  :interests => [],
  :cds_override => false,
}
o = OptionParser.new do |opts|
  opts.banner = "
    Usage: #{SCRIPT_NAME} <arguments>

    Given a GenBank file (which may have multiple GenBank entries in it) output a tab delimited summary
"
  opts.on("--accession", "Print accession") do |f|
    options[:interests].push lambda {|e|
      e.accession
    }
  end
  opts.on("--pubmed", "Print PubMed ID of associated article") do |f|
    options[:interests].push lambda {|e|
      e.references.collect{|ref| ref.pubmed}.join(', ')
    }
  end
  opts.on("--title", "Print title of associated article") do |f|
    options[:interests].push lambda {|e|    
      e.references.collect{|ref| ref.title}.join(', ')
    }
  end
  opts.on("--taxonomy", "Print taxonomy") do |f|
    options[:interests].push lambda {|e|
      e.taxonomy
    }
  end
  opts.on("--organism", "Print actual organism name") do |f|
    options[:interests].push lambda {|e|
      e.organism
    }
  end
  opts.on("--source:note", "Print /note of each feature") do |f|
    options[:interests].push lambda {|e|
      e.features.select{|feature|
        feature.feature == 'source'
      }.collect{|feature|
        feature['note']
      }.join(', ')
    }
  end
  opts.on("--source:isolation_source", "Print /isolation_source of each feature") do |f|
    options[:interests].push lambda {|e|
      e.features.select{|feature|
        feature.feature == 'source'
      }.collect{|feature|
        feature['isolation_source']
      }.join(', ')
    }
  end
  opts.on("--source:country", "Print /country of each feature") do |f|
    options[:interests].push lambda {|e|
      e.features.select{|feature|
        feature.feature == 'source'
      }.collect{|feature|
        feature['country']
      }.join(', ')
    }
  end
  opts.on("--cds:translation:fasta", "Print amino acid sequence of each CDS feature in FASTA format") do |f|
    if options[:interests].empty?
      options[:cds_override] = true
    else
      raise "Cannot specify --cds:translation:fasta with anything else"
    end
  end

  # logger options
  opts.on("-q", "--quiet", "Run quietly, set logging to ERROR level [default INFO]") do |q|
    Bio::Log::CLI.trace('error')
  end
  opts.on("--logger filename",String,"Log to file [default #{options[:logger]}]") do | name |
    options[:logger] = name
  end
  opts.on("--trace options",String,"Set log level [default INFO]. e.g. '--trace debug' to set logging level to DEBUG") do | s |
    Bio::Log::CLI.trace(s)
  end
end
o.parse!

# Setup logging
Bio::Log::CLI.logger(options[:logger]) #bio-logger defaults to STDERR not STDOUT, I disagree
log = Bio::Log::LoggerPlus.new(LOG_NAME)
Bio::Log::CLI.configure(LOG_NAME)

# Logic for the script
if options[:cds_override]
  Bio::FlatFile.foreach(ARGF) do |gb|
    first = true
    accession = gb.accession
    gb.features.select{|feature|
        feature.feature == 'CDS'
  }.each{|feature|
    if !feature['protein_id'].nil?
      protein_id = feature['protein_id'][0]
    else
      protein_id = 'unknown_protein_id'
    end
    puts ">#{accession}:#{protein_id}:#{feature.position}"
    puts feature['translation']
  }
  end
  
else
  Bio::FlatFile.foreach(ARGF) do |gb|
    first = true
    options[:interests].each do |interest|
      if first
        first = false
      else
        print "\t"
      end
      print interest.call(gb)
    end
    puts
  end
end