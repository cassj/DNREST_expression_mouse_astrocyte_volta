##### 
#
# This file will 
#
# USAGE
#
# You will need an AWS EC2 account to use the Capfiles
# Please see http://aws.amazon.com/ec2/
# Make sure you have create an ssh key in order to access
# EC2 instances
#
# To use this Capfiles, you will need to have the following
# installed (tested on Ubuntu and CentOS):
#
# git:        http://git-scm.com/
# ruby:       http://ruby-lang.org/
# RubyGems:   http://rubygems.org/
# 
# Install the gems you need with:
#
# sudo gem install capistrano
# sudo gem install amazon-ec2
# sudo gem install json
#
# Get the catpaws gem from github and build it
# 
# git clone git@github.com:cassj/catpaws.git
# cd catpaws
# rake gemspec
# rake build
# sudo gem install pkg/catpaws-*.gem
# 
# Note that this is a bit of a hack to give me Capistrano EC2:start and stop tasks.
# At some point I will come up with a better solution, I wouldn't recommend using it
# for anything else. 
#
# Finally, set the following environment variables appropriately
# for your AWS account:
#
# AMAZON_ACCESS_KEY
# AMAZON_SECRET_ACCESS_KEY
# EC2_URL (defaults to us-east-1.ec2.amazonaws.com)
# EC2_KEY (the name of the key registered with EC2, with which you will access )
# EC2_KEYFILE (the location of the key file. Alternatively, you can use ssh-agent)
# 
#####


#### Congfiguration ####

require 'catpaws/ec2'

set :aws_access_key,  ENV['AMAZON_ACCESS_KEY']
set :aws_secret_access_key , ENV['AMAZON_SECRET_ACCESS_KEY']
set :ec2_url, ENV['EC2_URL']
set :key, ENV['EC2_KEY'] #this should be the name of the key in aws, not the actual keyfile
set :ssh_options, {
  :keys => [ENV['EC2_KEYFILE']],
  :user => "ubuntu"
}
set :sudo_password, ''
set :ami, 'ami-52794c26' #32-bit ubuntu server (eu-west-1)
set :instance_type, 'm1.small'
set :working_dir, '/mnt/astrocytes'
set :script_dir, working_dir+'/scripts'
set :status_file, 'status.txt'

set :group_name, 'xdnvev'
set :nhosts, 1

set :git_url, ''


#### Tasks ####

desc "About this project"
task :about, :hosts => 'localhost' do
  puts <<eos
 Project:      REST/NRSF in Astrocytes
 Experiment:   Expression data from astrocytes infected with Dom-Neg Rest vs Empty Vector
 Publication:  
 Author:       Manuela Volta
 Author:       Chiara Soldati
 Author:       Cass Johnston
 Author:       Noel Buckley
 Contact:      Cass Johnston 
 Email:        caroline.johnston@kcl.ac.uk
eos
end
  
desc "Install git and add git key to server and co the repo"
task :git_key, :roles => group_name do
   gitkey = ENV['GIT_KEY'] 
   user = variables[:ssh_options][:user]
   if gitkey!=""
     upload(gitkey, "/home/#{user}/.ssh/id_rsa")
     upload("#{gitkey}.pub", "/home/#{user}/.ssh/id_rsa.pub")
   end
   run "sudo apt-get -y install git-core"
end
before "git_key", "EC2:start"

desc "install R on all running instances in group group_name"
task :install_r, :roles  => group_name do
  sudo "mkdir -p #{script_dir}"
  user = variables[:ssh_options][:user]
  sudo "chown #{user} #{script_dir}"
  sudo 'apt-get update'
  sudo 'apt-get -y install r-base'
  sudo 'apt-get -y install build-essential libxml2 libxml2-dev libcurl3 libcurl4-openssl-dev'
  run "wget --no-check-certificate '#{git_url}/R_setup.R' -O #{script_dir}/R_setup.R"
  run "cd #{script_dir} && chmod +x R_setup.R"
  sudo "Rscript #{script_dir}/R_setup.R"
end
before "install_r", "EC2:start"
  

desc "fetch the raw expression data to an EC2 instance"
task :get_expression_data, :roles => group_name do
  sudo 'mkdir -p /mnt/expression_data'
  user = variables[:ssh_options][:user]
  sudo "chown #{user} /mnt/expression_data"
  run 'wget "http://mng.iop.kcl.ac.uk/data_dump/Astro-REST-DN-raw.csv" -O /mnt/expression_data/Astro-REST-DN-raw.csv'
end
before "get_expression_data", "EC2:start"



desc "run QC checks on the raw data"
task :qc_expression_data, :roles => group_name do
#  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/illumina_qc.R" -O /mnt/scripts/.R'
#  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/limma_xpn.R" -O /mnt/scripts/limma_xpn.R'
#  run 'Rscript /mnt/scripts/limma_xpn.R'
end
before "qc_expression_data", "EC2:start"


desc "run pre-processing on expression data"
task :pp_expression_data, :roles => group_name do
  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/qw.R" -O /mnt/scripts/qw.R'
  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/limma_xpn.R" -O /mnt/scripts/limma_xpn.R'
  run 'Rscript /mnt/scripts/limma_xpn.R'
end
before "pp_expression_data", "EC2:start"


desc "run QC checks on the pre-processed quality control"
task "pp_qc_expression_data", :foles => group_name do
  #do some stuff
end  


desc "Make an IRanges object from expression data"
task :irange_expression_data, :roles => group_name do
  run 'wget "http://github.com/cassj/my_bioinfo_scripts/raw/master/liftOver.R" -O /mnt/scripts/liftOver.R'
  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/xpn_csv_to_iranges.R" -O /mnt/scripts/xpn_csv_to_iranges.R'
  sudo 'mkdir -p /mnt/lib'
  user = variables[:ssh_options][:user]
  sudo "chown #{user} /mnt/lib"
  run 'wget "http://hgdownload.cse.ucsc.edu/goldenPath/mm8/liftOver/mm8ToMm9.over.chain.gz" -O /mnt/lib/mm8ToMm9.over.chain.gz'
  run 'gunzip -c /mnt/lib/mm8ToMm9.over.chain.gz > /mnt/lib/mm8ToMm9.over.chain'
  run  "wget http://mng.iop.kcl.ac.uk/data_dump/Mouse-6_V1.csv -O /mnt/lib/Mouse-6_V1.csv" 
  
  #reMOAT data, to get probe sequence and genome location (mm8, although they seem to have mm9
  #now so perhaps we should update?
  run "wget -O /mnt/lib/IlluminaMouseV1.txt  http://www.compbio.group.cam.ac.uk/Resources/Annotation/IlluminaMouseV1.txt"
  
  sudo 'wget -O /usr/bin/liftOver http://hgdownload.cse.ucsc.edu/admin/exe/linux.i386/liftOver'
  sudo 'chmod +x /usr/bin/liftOver'
  run 'Rscript /mnt/scripts/xpn_csv_to_iranges.R'
end
before "irange_expression_data","EC2:start"  
  

desc "map irange position to nearest Ensembl gene"
task :expression_to_ensembl, :roles => group_name do
  
  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/mm9RDtoGenes.R" -O /mnt/scripts/mm9RDtoGenes.R'
  run 'Rscript /mnt/scripts/mm9RDtoGenes.R filename=\\"/mnt/expression_data/RangedData_Limma.R\\"'
end
before "expression_to_ensembl", "EC2:start"  

desc "make a csv file or the annotated ranged data"
task :expression_to_csv,  :roles => group_name do
  run 'wget "http://github.com/cassj/manu_rest_project/raw/master/annoRDtoCSV.R" -O /mnt/scripts/annoRDtoCSV.R'
  run 'Rscript /mnt/scripts/annoRDtoCSV.R filename=\\"/mnt/expression_data/AnnoRangedData_Limma.R\\"'
end
before "expression_to_csv", 'EC2:start'

  
desc "fetch expression results"
task :fetch_expression,  :roles => group_name do
  sudo 'tar -cvzf /mnt/expression_data.tgz /mnt/expression_data'
  download "/mnt/expression_data.tgz", "expression_data.tgz"
  `tar -xvzf expression_data.tgz`
  `rm expression_data.tgz`
  `mv mnt results`
end
before "fetch_expression", "EC2:start"
  
  
  
desc "Run whole XDNvEV pre-processing"
task :xdnvev,  :roles => group_name do
  puts "Running, this may take a while..."
end 
before "xdnvev", "EC2:start", "install_r", "get_expression_data", "pp_expression_data", "irange_expression_data", "expression_to_ensembl", "fetch_expression", "EC2:stop"


#end
