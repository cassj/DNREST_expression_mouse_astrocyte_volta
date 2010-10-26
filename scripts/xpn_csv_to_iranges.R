#!/usr/bin/Rscript

qw <- function(...) {
  as.character(sys.call()[-1])
}

liftOver<-function(data, chain.file, ucsc.format=T, chr.col="chr", start.col="start",end.col="end"){

  #data should be a matrix or dataframe with cols for chr, start and end
  #TODO: Or a RangedData / IRange object, 
 
  this<-data.frame(chr=as.character(data[,chr.col]),start=as.numeric(data[,start.col]),end=as.numeric(data[,end.col]), stringsAsFactors=F)

  #Normal counting specifies ranges in 1-based, fully closed form.
  #UCSC specifies ranges in  0-based, half open
  if (!ucsc.format){
      this$start<-this$start-1
  }

  #use the chrstartend as an id so we can map back to the original data
  ids = paste(as.character(data[,chr.col]),data[,start.col],data[,end.col], sep=".")
  this <- cbind(this, ids)
  #If we have duplicate positions, remove them for the liftOver 
  this <- unique(this)
  #we also need to chuck out anything that doesn't have positional data.
  no.chr <- which(is.na(this[,1]))
  no.start <- which(is.na(this[,2]))
  no.end <- which(is.na(this[3]))

  inds <- unique(c(no.chr,no.start,no.end))

  if( length(inds)>0 ){ this <- this[-1*inds,] }
  
  
  in.bed <- tempfile()

  #need to watch we don't get scientific notation printed out
  options(scipen=10)
  write.table(this, file=in.bed, sep="\t", row.names=F, col.names=F, quote=F)

  out.bed <- tempfile()
  out.um.bed <- tempfile()
  lo.cmd <- paste("liftOver", in.bed, chain.file, out.bed, out.um.bed)
  system(lo.cmd)

  try(
    new.bed<-read.table(out.bed, sep="\t") 
      ,silent=T)
  try(
    new.um <- read.table(out.um.bed, sep="\t")
      ,silent=T)
  
  #throw away the files
  unlink(c(in.bed, out.bed, out.um.bed))

  if (!exists('new.bed')){stop("No successful mappings")}

  #use the ids as rownames chuck out the column
  #order in the same order as our original data
  #which should stick NAs in for anything that can't be mapped
  rownames(new.bed) <- new.bed[,4]
  new.bed <- new.bed[,-4]
  new.bed <- new.bed[ids,]

  if(!ucsc.format){
   #put the data back to 1-based
   new.bed[,2] <- new.bed[,2]+1
  }

  #replace the new positions in the original dataset
  data[,chr.col] <- new.bed[,1]
  data[,start.col] <- new.bed[,2]
  data[,end.col] <- new.bed[,3]

  #TODO: return some information about the data that won't map
  
  return(data)
  
}


options(stringsAsFactors = FALSE);
args <- commandArgs(trailingOnly=TRUE)

# load datafile from pp_expression_data
limmafile = args[1]
sentrix.annot = args[2]
remoat.annot = args[3]

outfile = args[2]
limma <- read.csv(filename)
limma<-limma[,-1]
colnames(limma)[1]<-"IlluminaID"


######
# Annotation from illumina
lumi.annot<-read.csv(sentrix.annot) 

#remove anything with many-to-one probe-to-target mapping, there are only a few
dups<-as.character(lumi.annot$Target[which(duplicated(lumi.annot$Target))])
lumi.annot<-lumi.annot[-1*which(as.character(lumi.annot$Target) %in% dups),]
rownames(lumi.annot)<-as.character(lumi.annot$Target)

#map the TargetID back to a ProbeID using the original Illumina data
ProbeID<-lumi.annot[as.character(limma$IlluminaID), "ProbeId"]
limma<-cbind(limma, ProbeID)
limma<-limma[-1*(which(is.na(as.character(limma$ProbeID)))),]
rownames(limma)<-as.character(limma$ProbeID)


######
# Annotation from ReMOAT

# sentrix mouse ref 6 amnot from Illumina has old targetIDs, which are no longer in use
# get the probe sequences from reMoat data
old.annot<-read.csv(remoat.annot, sep="\t", header=T)
rownames(old.annot)<-as.character(old.annot$ProbeId0)

limma.annot<-cbind(limma, old.annot[as.character(limma$ProbeID),])

#ditch anything for which we have no annotation
remove<-which(is.na(limma.annot$Chromosome))
if(length(remove)>0){limma.annot<-limma.annot[-remove,]}

remove<-which(is.na(limma.annot$Start))
if(length(remove)>0){limma.annot<-limma.annot[-remove,]}

remove<-which(is.na(limma.annot$End))
if(length(remove)>0){limma.annot<-limma.annot[-remove,]}


##and liftOver the mm8 probe positions
to.map<-limma.annot[,qw(Chromosome, Start, End)]
colnames(to.map) <- c("chr","start","end")
mapped <- liftOver(to.map , chain.file="lib/mm8ToMm9.over.chain")
limma.annot[,qw(Chromosome, Start, End)] <- mapped[,qw(chr,start,end)]

#ditch anything for which we have no region
remove<-which(is.na(limma.annot$Chromosome))
if(length(remove)>0){limma.annot<-limma.annot[-remove,]}

ids<-grep('random', limma.annot$Chromosome)
if(length(ids)>0){limma.annot<-limma.annot[(-1*ids),]}


#and just a few are wierdly the wrong length, no idea why.
#liftOver could explain slight variation from 50, but not much

remove <- which((limma.annot$End - limma.annot$Start) > 100 )
if(length(remove)>0){limma.annot<-limma.annot[-remove,]}


#create a RangedData object for the region start and end:
library(IRanges)

#fix colnames
colnames(limma.annot)[c(1,2,5,6,25,26)]<-qw(IlluminaSentrixTargetID, log2FoldChange, pVal, FDR, SpliceJunction, PerfectMatch)


#we have to give them names to avoid a bug in ChIPpeakAnnot if we want to use it later
rd.limma <- RangedData(ranges = IRanges(
        	           start= limma.annot$Start,
                	   end = limma.annot$End,
	                   names = as.character(limma.annot$IlluminaSentrixTargetID),
                   ),
                 space = as.character(limma.annot$Chromosome),
                 values = limma.annot[,
                   qw(log2FoldChange, AveExpr,t,pVal, FDR, B, Search_key0, Target0, 
                      ProbeId0, Transcript0, Accession0, Symbol0, Definition0, Sequence,
                      Strand, Cytoband, BlastHitType, OtherHits, SpliceJunction, PerfectMatch,
                      Length_match, X.Similarity, Overall.Similarity, GenBanks, Symbols,
                      Description, Comments
                      )]
                 )

#And save the result
save(rd.limma, file="expression_data/RangedData_Limma.R")
write.csv(limma.annot, file="expression_data/limma_annot.csv")



