# script for aggregating multiple measurements
# - usage e.g.
#   Rscript agg.R ./measures/y24_mo01_d09_h22_m59_s39.json ./measures/y24_mo01_d09_h22_m59_s40.json
# - generates cpu and mem pdfs in the dir of the first given file
# - plots contain the given plots in grey and the aggregated plot in red
# - vertical line visualizes aggregated endtime
# - merge warnings are handled

library(jsonlite)
library(ggplot2)

# get path to json s from arg
args <- commandArgs(trailingOnly = TRUE)
if(length(args) < 1) {
    stop("missing file args")
}
# get the data
plot_data <- list()
for(i in 1:length(args)){
  m <- fromJSON(args[i])
  xs <- as.numeric(m$ts)
  y1s <- as.numeric(gsub("%","",m$y$MemPerc))
  y2s <- as.numeric(gsub("%","",m$y$CPUPerc))
  # remove first and last entry, they include stats before and after script/query execution
  xs <- xs[-c(1, length(xs))]
  y1s <- y1s[-c(1, length(y1s))]
  y2s <- y2s[-c(1, length(y2s))]
  plot_data[[i]] <-
  data.frame(
    x = xs,
    y1 = y1s,
    y2 = y2s
  )
}
# set relativ times (if not done already, but that doesnt matter)
for(i in 1:length(plot_data)){
  ts <- plot_data[[i]]$x
  s <- ts[1]
  for(j in 1:length(ts)){
    plot_data[[i]]$x[j] <- ts[j]-s
  }
}
# get all timestamps
mergeTS <- function(a,b){
  merge(a,b,by="x",all=TRUE)
}
plot_data_merged <- Reduce(mergeTS,plot_data)
# rename columns cuz reduce messed it up
# however assume columns structured like this: 
# x  | y1_1 | y2_1 | y1_2 | y2_2 | ..
# now becoming:
# c1 | c2   | c3   | c4   | c5   | ..
colnames(plot_data_merged) <- paste0("c", seq_along(colnames(plot_data_merged)))

# linear interpolate the missing values 
interpolate <- function(df,xs,ys,cNr){
  cn <- paste0("c",cNr) 
  na_idxs = which(is.na(df[[cn]]))
  #print(na_idxs)
  for(idx in na_idxs){
     i <- approx(xs, ys, df$c1[idx], method = "linear", rule = 2, f = 0, ties = mean)$y
     df[[cn]][idx] <- i
  }
  df
}
plots_ip<-plot_data_merged
for(i in 1:length(plot_data)){
  cNr<-2*i
  plots_ip <- interpolate(plots_ip,plot_data[[i]]$x,plot_data[[i]]$y1,cNr+0)
  plots_ip <- interpolate(plots_ip,plot_data[[i]]$x,plot_data[[i]]$y2,cNr+1)
}
#print(plot_data_merged[[paste0("c",2)]])
# calculate the mean, fml
aggregate <- function(plots,size,os,rNr){
  m <- 0
  for(i in 1:plots){
    cn <- paste0("c",2+(i-1)*size+os)
    m <- m + plots_ip[[cn]][rNr]  
  }
  m / plots
}
plots_ip$mean_mem<-c() #y1
plots_ip$mean_cpu<-c() #y2
for(i in 1:length(plot_data)){
  for(j in 1:length(plots_ip$c1)){
    plots_ip$mean_cpu[j] <- aggregate(length(plot_data),2,1,j)
    plots_ip$mean_mem[j] <- aggregate(length(plot_data),2,0,j)
  }
}
# plot it
# base r plotting multiple lines didnt work last time so i wont even try it, however ggplot2 seems to be doing a good job
# needs some special formed dataframe to work with
# offset, statssize, aggregationname, aggregationdata
createPlotDF <- function(os,size,name,agg){
  xs <- rep(plots_ip$c1, times = length(plot_data)+1)
  ns <- rep(paste(name,"mean"), each=nrow(plots_ip))
  ns <- c(ns,rep(paste0(name,1:length(plot_data)),each=nrow(plots_ip)))
  vs <- agg
  for(i in 1:length(plot_data)){
    n <- paste0("c",2+(i-1)*size+os)
    vs <- c(vs, plots_ip[[n]])
  }
  df <- data.frame(
    x = xs,
    group = ns,
    y = vs
  )
}
# calc end point
m <- 0
for(i in 1:length(plot_data)){
  m <- m+plot_data[[i]]$x[nrow(plot_data[[i]])]
}
endTs <- m / length(plot_data)
# nanseconds to seconds fct
nsToS <- function(x){
  x / 1e9
}
# shorthand round fct
r <- function(x){
  round(x,digits=2)
}
# shorthand fct for getting base name of file
bn <- function(p){
  gsub("\\..*$", "", basename(p))
}
# use dir of first arg file to place stuff to
fb <- paste0(sub("/[^/]*$", "", args[1]),"/mean_",bn(args[1]),"-",bn(args[length(args)]),"_")
# dataframe, stat-name, yrangevector w two elem containing range limits, meanstatsname for column in plots_ip containg agg data
createPlot <- function(df,stat,yrange){
  # calc some agg stats:
  # end is calc, so get y for that via lin int.
  mn <- paste0("mean_",stat)
  endTsY <- approx(plots_ip$c1, plots_ip[[mn]], endTs, method = "linear", rule = 2, f = 0, ties = mean)$y
  s <- subset(plots_ip,c1<=endTs)
  m <- c(s[[mn]],endTsY)
  stats <- paste("min:",r(min(m)),"max:",r(max(m)),"avg:",r(mean(m)))

  n <- paste(stat,"mean")
  # plot w:
  # - other execpt mean stat as grey lines
  # - vertical line for marking mean end
  # - x-value of vline should be visible, sec and ms important
  # - draw x-axis in seconds
  # - set a y-axis range
  # - add metadata stuff
  p <- ggplot(data = df, aes(x=x, y=y,color=group,group=group))+
    geom_line(data=subset(df,group!=n),color="grey")+
    geom_line(data=subset(df,group==n),color="red")+
    geom_vline(xintercept=endTs,linetype="dashed",color="red")+
    annotate("text",x=endTs,y=0,label=r(nsToS(endTs)),vjust=0)+
    scale_x_continuous(labels = nsToS)+
    coord_cartesian(ylim = yrange)+
    labs(
      x="execution time in seconds",
      y=paste(stat,"usage in %"),
      title=paste(n,"usage",stats)
    )
  ggsave(paste0(fb,stat,".pdf"), width = 10, height = 5, p)
}
# plot cpu
df <- createPlotDF(1,2,"cpu",plots_ip$mean_cpu)
# 100 - one cpu; 800 - eight cpus
createPlot(df,"cpu",c(0,150))
# plot mem
df <- createPlotDF(0,2,"mem",plots_ip$mean_mem)
# 100 - 8 GB
createPlot(df,"mem",c(0,15))

