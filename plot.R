# install.packages("jsonlite")
library(jsonlite)
library(graphics)

# get path to json from first arg
args <- commandArgs(trailingOnly = TRUE)
if(length(args[1]) != 1) {
    stop("missing file arg")
}
# Read JSON data from the file
plot_data <- fromJSON(args[1])

# regarding plotting, $ts is x and $x is the label
x_values <- as.numeric(plot_data$ts)
y1_values <- as.numeric(gsub("%","",plot_data$y$MemPerc))
y2_values <- as.numeric(gsub("%","",plot_data$y$CPUPerc))
x_labels <- c(plot_data$x)
# the first and last entry contains times in which there was no execution, which mess up statistical stuff
y1_values_exec = y1_values[-c(1, length(y1_values))]
y2_values_exec = y2_values[-c(1, length(y2_values))]
# printing all labels messes up the output, lets just print it each n = 3 
poss <- seq(1,length(plot_data$x),by=3)
# always include last elem
if(poss[length(poss)] != length(plot_data$x)){
    poss <- c(poss,length(plot_data$x))
}
x_values_cut <- x_values[poss]
x_labels_cut <- x_labels[poss]
# cut to important time parts
x_labels_cut <- substring(x_labels_cut,first=10,last = 19)
# path without extension
fb <- substring(args[1],first=1,last=nchar(args[1])-5)

# create plot vis. mem usage
# paste0 does str concat without adding spaces
pdf(paste0(fb,"_Mem.pdf"), width = 10, height = 5)
# ylim sets y-axis range from 0-20
plot(x = x_values, y = y1_values, ylim = c(0,20), type = "o", col = "blue", pch = 16, main = "memory usage", xlab = "", ylab = "memory usage in %",axes=FALSE)
# axes are disabled, with axis enabled separatly
axis(2)
axis(1,at = x_values_cut, labels = x_labels_cut,las = 2)
# add a legend with some useful graph data
legend("topright", legend = c(paste("Memory usage, execution min:",min(y1_values_exec),"max:",max(y1_values_exec),"avg:",mean(y1_values_exec))), col = c("blue"), lwd = 2)
grid()
dev.off()

# create plot vis. cpu usage
pdf(paste0(fb,"_CPU.pdf"), width = 10, height = 5)
# note: 800 cuz 100% relativ to one cpu, in my case docker uses 8 cpus
plot(x = x_values, y = y2_values, ylim = c(0,800),type = "o", col = "red", pch = 16, main = "cpu usage", xlab = "", ylab = "cpu usage in %",axes=FALSE)
axis(2)
axis(1,at = x_values_cut, labels = x_labels_cut,las = 2)
legend("topright", legend = c(paste("cpu usage relative to one cpu, execution min:",min(y2_values_exec),"max:",max(y2_values_exec),"avg:",mean(y2_values_exec))), col = c("red"), lwd = 2)
grid()
dev.off()


