library(tidyverse)
source("sim_data_poi_gam_two_grp.R")
source("ancom_bc.R")

# The number of taxa, library size, and sample size
n.taxa = 1000; balanced.micro.load = FALSE; balanced.lib.size = TRUE 
samp.frac = "small"; n.samp = "50_50"

# The proportion of differentially abundant taxa
prop.diff=c(0.05, 0.15, 0.25)

# Set seeds
iterNum=100
abn.seed=1
obs.seed=1:100

# Define the simulation parameters
simparams=expand.grid(n.taxa, n.samp, prop.diff, abn.seed, obs.seed,
                      balanced.micro.load, balanced.lib.size, samp.frac)
colnames(simparams)=c("n.taxa", "n.samp", "prop.diff", "abn.seed", "obs.seed",
                      "balanced.micro.load", "balanced.lib.size", "samp.frac")
simparams=simparams%>%separate(col = n.samp, into = c("n.samp.grp1", "n.samp.grp2"), sep = "_")
simparams=simparams%>%arrange(n.taxa, n.samp.grp1, prop.diff, abn.seed, obs.seed)
simparams.list=apply(simparams, 1, paste0, collapse="_")

simparamslabels=c("n.taxa", "n.samp.grp1", "n.samp.grp2","prop.diff", "abn.seed", "obs.seed",
                  "balanced.micro.load", "balanced.lib.size", "samp.frac")

library(doParallel)
library(foreach)

detectCores()
myCluster=makeCluster(4, type = "FORK")
registerDoParallel(myCluster)

start_time <- Sys.time()
simlist=foreach(i = simparams.list, .combine = 'cbind') %dopar% {
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
  obs.abn=test.dat$obs.abn
  meta.data=cbind(Sample.ID=paste0("sub", seq(n.samp.grp1+n.samp.grp2)), 
                  group=rep(c(1, 2), c(n.samp.grp1, n.samp.grp2)))
  d=log(test.dat$samp.frac)
  
  # Pre-processing
  feature.table=obs.abn; sample.var="Sample.ID"; group.var="group"
  zero.cut=0.90; lib.cut=1000; neg.lb=FALSE
  pre.process=feature_table_pre_process(feature.table, meta.data, sample.var, 
                                        group.var, zero.cut, lib.cut, neg.lb)
  feature.table=pre.process$feature.table
  group.name=pre.process$group.name
  group.ind=pre.process$group.ind
  struc.zero=pre.process$structure.zeros
  
  # Paras for ANCOM-BC
  grp.name=group.name; grp.ind=group.ind; adj.method="bonferroni"
  tol.EM=1e-5; max.iterNum=100; perNum=1000; alpha=0.05
  
  # Run ANCOM-BC
  suppressWarnings(out <- try(ANCOM_BC(feature.table, grp.name, grp.ind, struc.zero,
                                       adj.method, tol.EM, max.iterNum, perNum, alpha), 
                              silent = TRUE))
  if (inherits(out, "try-error")) {
    bias.true=NA; bias.em=NA; bias.wls=NA; bias.diff=NA
  }else{
    bias.true=mean(d[1:n.samp.grp1]) - mean(d[(n.samp.grp1+1):(n.samp.grp1+n.samp.grp2)])
    bias.em=out$bias.em[2]; bias.wls=out$bias.wls[2]
  }
  c(bias.true, bias.em, bias.wls)
}
end_time <- Sys.time()
end_time - start_time

stopCluster(myCluster)
write_csv(data.frame(simlist), "bias_var_em_wls.csv")
