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
set :ami, 'ami-52794c26' #32-bit ubuntu lucid server (eu-west-1)
set :instance_type, 'm1.small'
set :s3cfg, ENV['S3CFG'] #location of ubuntu s3cfg file
set :working_dir, '/mnt/work'

set :group_name, 'DNREST_expression_mouse_astrocyte_volta'
set :nhosts, 1

set :snap_id, `cat SNAPID`.chomp #empty until you've created a snapshot
set :vol_id, `cat VOLUMEID`.chomp #empty until you've created a new volume
set :ebs_size, 2  #We really don't need a lot of space for a basic differential expression study
set :ebs_zone, 'eu-west-1a'  #wherever your ami is
set :dev, '/dev/sdf'
set :mount_point, '/mnt/data'

set :git_url, 'http://github.com/cassj/DNREST_expression_mouse_astrocyte_volta/raw/master'

#cap EC2:start
#cap EBS:create (unless you want to use the one that already exists)
#cap EBS:attach
#cap EBS:format_xfs
#cap EBS:mount_xfs
#
# cap git_clone
# cap install_r
# cap install_s3
# 
#cap EBS:snapshot
#cap EBS:unmount
#cap EBS:detach
#cap EBS:delete
#cap EC2:stop

#### Tasks ####

#export GIT_KEY="/home/cassj/ec2/github_id_rsa"


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
  

desc "install R on all running instances in group group_name"
task :install_r, :roles  => group_name do
  user = variables[:ssh_options][:user]
  sudo 'apt-get update'
  sudo 'apt-get -y install r-base'
  sudo 'apt-get -y install build-essential libxml2 libxml2-dev libcurl3 libcurl4-openssl-dev'
  run "wget --no-check-certificate '#{git_url}/scripts/R_setup.R' -O #{working_dir}/R_setup.R"
  run "cd #{working_dir} && chmod +x R_setup.R"
  sudo "Rscript #{working_dir}/R_setup.R"
end
before "install_r", "EC2:start"


#install s3tools
desc "install s3tools"
task :install_s3, :roles =>group_name do
  sudo 'apt-get update'
  sudo 'apt-get -y install s3cmd'
  user = variables[:ssh_options][:user]
  file = File.open(s3cfg)
  upload(file, "/home/#{user}/.s3cfg")
end
before "install_s3", "EC2:start"

desc "fetch the raw expression data to an EC2 instance"
task :get_expression_data, :roles => group_name do
  
  s3_file = File.new("data/S3", "r")
  run "mkdir -p #{mount_point}/raw"
  s3_file.each{|f|
    run "cd #{mount_point}/raw && s3cmd get s3://#{f}"
    
  }
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
  run "mkdir -p #{working_dir/scripts}"
  run "cd #{working_dir/scripts} && curl http://github.com/cassj/DNREST_expression_mouse_astrocyte_volta/raw/master/scripts/limma_xpn.R > limma_xpn.R"
  run "cd #{working_dir/scripts} && curl http://github.com/cassj/DNREST_expression_mouse_astrocyte_volta/raw/master/scripts/qw.R > qw.R"
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
