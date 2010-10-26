# Probably should be a wrapper around the C code from the Kent Source, but will have to
# check licensing issues. For now, just do a system call:

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
