library(tidyverse)
source("sim_data_poi_gam_two_grp.R")

# The number of taxa, library size, and sample size
n.taxa = 1000; balanced.micro.load = TRUE; balanced.lib.size = TRUE 
samp.frac = "small"; n.samp = c("20_30", "50_50")

# The proportion of differentially abundant taxa
prop.diff=c(0.05, 0.15, 0.25)

# Set seeds
iterNum=100
abn.seed=seq(iterNum)

# Define the simulation parameters
simparams=expand.grid(n.taxa, n.samp, prop.diff, abn.seed, 
                      balanced.micro.load, balanced.lib.size, samp.frac)
colnames(simparams)=c("n.taxa", "n.samp", "prop.diff", "abn.seed", 
                      "balanced.micro.load", "balanced.lib.size", "samp.frac")
simparams=simparams%>%mutate(obs.seed=abn.seed+1)
simparams=simparams%>%separate(col = n.samp, into = c("n.samp.grp1", "n.samp.grp2"), sep = "_")
simparams=simparams%>%arrange(n.taxa, n.samp.grp1, prop.diff, abn.seed, obs.seed)
simparams.list=apply(simparams, 1, paste0, collapse="_")

simparamslabels=c("n.taxa", "n.samp.grp1", "n.samp.grp2","prop.diff", "abn.seed",
                  "balanced.micro.load", "balanced.lib.size", "samp.frac", "obs.seed")

library(doParallel)
library(foreach)

start_time <- Sys.time()
simlist=foreach(i = simparams.list, .combine = 'cbind') %do% {
  # i = simparams.list[[1]]
  print(i)
  params = strsplit(i, "_")[[1]]
  names(params) <- simparamslabels
  
  # Paras for data generation
  n.taxa=as.numeric(params["n.taxa"])
  n.samp.grp1=as.numeric(params["n.samp.grp1"])
  n.samp.grp2=as.numeric(params["n.samp.grp2"])
  prop.diff=as.numeric(params["prop.diff"])
  abn.seed=as.numeric(params["abn.seed"])
  obs.seed=as.numeric(params["obs.seed"])
  balanced.micro.load=as.logical(params["balanced.micro.load"])
  balanced.lib.size=as.logical(params["balanced.lib.size"])
  samp.frac=params["samp.frac"]
  
  # Data generation
  low.abn=50; med.abn=200; high.abn=10000; struc.zero.prop=0.20; out.zero.prop=0.05
  test.dat=abn.tab.gen1(n.taxa, n.samp.grp1, n.samp.grp2, low.abn, med.abn, high.abn,
                        prop.diff, abn.seed, obs.seed, struc.zero.prop, out.zero.prop,
                        balanced.micro.load, balanced.lib.size, samp.frac)
  
  meta.data=data.frame(group=rep(c(1, 2), c(n.samp.grp1, n.samp.grp2)))
  countdata=test.dat$obs.abn
  
  zero.threshold=0.90
  taxa.info.ind=apply(countdata, 1, function(x) sum(x==0)/(n.samp.grp1+n.samp.grp2))
  feature_table=round(countdata[which(taxa.info.ind<zero.threshold), ])+1L
  feature_table.scale=apply(feature_table, 2, function(x) x/sum(x))
  
  # Run wilcox2
  p.val=apply(feature_table.scale, 1, function(x) 
    wilcox.test(x[1:n.samp.grp1], x[(n.samp.grp1+1):(n.samp.grp1+n.samp.grp2)])$p.value)
  FDR=p.adjust(p.val, method = "BH")
  
  res=data.frame(diff.test=ifelse(FDR<0.05, 1, 0), 
                 diff.ind=test.dat$diff.taxa[which(taxa.info.ind<zero.threshold)])
  
  # FDR
  FDR=ifelse(sum(res$diff.test==1, na.rm = T)==0, 0, 
             sum(ifelse(res$diff.ind==0&res$diff.test==1, 1, 0), na.rm = T)/sum(res$diff.test==1, na.rm = T))
  
  # Power
  power=sum(ifelse(res$diff.ind!=0&res$diff.test==1, 1, 0), na.rm = T)/sum(res$diff.ind!=0, na.rm = T)
  
  c(FDR, power)
}
end_time <- Sys.time()
end_time - start_time

write_csv(data.frame(simlist), "fdr_power_wilcox_tss_small.csv")
